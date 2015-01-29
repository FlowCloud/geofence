#include <TinyGPS++.h>
#include <XMLNode.h>

// The Datastore class wraps the Flow datastore in a C++ object and
// allows us easy access to load, clear and to save a XML node
// This class is implemented in Datastore.pde
class DataStore
{
public:
	DataStore(char *name);
	bool load();
	bool clear(char *string);
	bool save(XMLNode &node);
private:
	char *name;
	FlowDataStore _datastore;
};

  /* We want to map pins 5 and 7 to Serial2 (for RX and TX respectively).
	 Serial2 uses using the WiFire's UART6 and both pin 5 and 7 support being mapped
	 to the relevant peripheral (U6RX and U6TX) .
	 Note that pin 5 is chosen (actually it is already mapped to U6RX by default)
	 as it is a 5v tolerant pin, so the UART chip connected may operate at 5v levels.
	 It is also necessary that the UART chip accepts 3v3 as a logic HIGH as this
	 is the logic HIGH provided by pin 7.

	 For this example the MAX232 is used, which operates at 5v but accepts 3v3 as HIGH */
#define SERIAL2_RX_PIN (5)
#define SERIAL2_TX_PIN (7)

#define BTN1 (46)
#define BTN2 (47)

// The GPS module we will be using uses a 9600-baud RS232 connection
#define GPSBaud (9600)

// Object for the tinyGPS++ library we are using
TinyGPSPlus gps;

// Access to the Flow datastore named "GPSReading"
DataStore datastore("GPSReading");

// log every minute
#define LOGGING_PERIOD (1 * 60 * 1000)

void setup()
{
	// use the same baud rate as the boot console so that we don't have to change the
	// serial connection baud rate
	Serial.begin(115200);

	// We are not reading from Serial and don't mind sharing it with libappbase
	g_EnableConsole = true;
	g_EnableConsoleInput = true;

	Serial.println("RS232_GPS.ino  ");
	Serial.print("Using TinyGPS++ library v. ");
	Serial.println(TinyGPSPlus::libraryVersion());

	Serial.print("Bringing up GPS serial connection... ");

	// remap our desired RX and TX pins to U6 (corresponding to Serial2)
	mapPps(SERIAL2_RX_PIN, PPS_IN_U6RX);
	mapPps(SERIAL2_TX_PIN, PPS_OUT_U6TX);

	Serial2.begin(GPSBaud);
	Serial.println("OK!");

	/* pin 29 is by default used for PPS_OUT_U6TX. We can leave it as this
	 * as well as pin 7, remap it to some other peripheral or we can just
	 * use it as a GPIO with
	pinMode(29, OUTPUT);
	 * or 
	pinMode(29, INPUT);
	 */

	// Load the datastore from FlowCloud
	Serial.println("Fetching datastore from FlowCloud... ");  
	if (!datastore.load()){
		Serial.println("FAILED!");
		for(;;);
	}

	Serial.println();
	Serial.println();
}

// read the current GPS location from the NMEA library to a XML node
void readGPSToXML(XMLNode &xml)
{

	// create a sting for the current datetime
	#define DATETIME_FIELD_LENGTH 32
	char datetimeStr[DATETIME_FIELD_LENGTH];
	time_t currentDateTimeSeconds;
	Flow_GetTime(&currentDateTimeSeconds);
	struct tm *currentDateTimeUTC = gmtime(&currentDateTimeSeconds);
	strftime(datetimeStr, DATETIME_FIELD_LENGTH, "%Y-%m-%dT%H:%M:%SZ", currentDateTimeUTC);

	XMLNode &readingTime = xml.addChild("gpsreadingtime");
	readingTime.addAttribute("type", "datetime");
	readingTime.addAttribute("index", "true");
	readingTime.setContent(datetimeStr);

	XMLNode &location = xml.addChild("location");
	XMLNode &lat = location.addChild("latitude");
	lat.setContent(gps.location.lat(), 9);
	XMLNode &lng = location.addChild("longitude");
	lng.setContent(gps.location.lng(), 9);
	XMLNode &readingAge = xml.addChild("readingage");
	readingAge.setContent(gps.location.age());

	XMLNode &satellites = xml.addChild("satellites");
	satellites.setContent(gps.satellites.value());

	XMLNode &altitude = xml.addChild("altitude");
	altitude.addAttribute("unit", "meters");
	altitude.setContent(gps.altitude.meters(), 3);

	XMLNode &speed = xml.addChild("speed");
	speed.addAttribute("unit", "mps");
	speed.setContent(gps.speed.mps(), 3);

	XMLNode &course = xml.addChild("course");
	course.setContent(gps.course.deg(), 3);

	XMLNode &hdop = xml.addChild("hdop");
	hdop.setContent(gps.hdop.value(), 3);
}

// save the current GPS location to the FlowCloud datastore
bool saveReadingToDatastore()
{
	bool result = false;
	if (gps.location.isValid())
	{

		XMLNode reading("gpsreading");
		readGPSToXML(reading);

		if (datastore.save(reading))
		{
			result = true;
		}
	} 
	else 
	{
		Serial.println("Not writing to datastore - location invalid");
	}

	return result;
}

void clearOldReadings()
{
	char clearCmd[256];
	strcpy(clearCmd, "@gpsreadingtime >= '");

	char datetimeStr[DATETIME_FIELD_LENGTH];
	time_t currentDateTimeSeconds;
	// can we make this actually remove all but 40 items?
	currentDateTimeSeconds -= (LOGGING_PERIOD / 1000) * 40; // ~40 items in history
	Flow_GetTime(&currentDateTimeSeconds);
	struct tm *currentDateTimeUTC = gmtime(&currentDateTimeSeconds);
	strftime(datetimeStr, DATETIME_FIELD_LENGTH, "%Y-%m-%dT%H:%M:%SZ", currentDateTimeUTC);


	strcat(clearCmd, datetimeStr);
	strcat(clearCmd, "'");
	datastore.clear(clearCmd);
	Serial.print("Clearing old datastore items ");
	Serial.println(clearCmd);
}

void loop()
{
	// record the time of the las save so we know when to next save
	// initially set this to long enough ago that we will always save
	// the current location when we first start up
	static long lastSave = -2*LOGGING_PERIOD;
	static int count = 0;

	while (Serial2.available() > 0)
	{
		if (gps.encode(Serial2.read()))
		{

			// if the configured period of time has passed then save a new reading
			if (millis() - lastSave > LOGGING_PERIOD)
			{
				lastSave = millis();

				// periodically clear old readings from the database
				if (count++ > 10)
				{
					count = 0;
					clearOldReadings();
				}

				// save a new reading
				if (!saveReadingToDatastore())
				{
					Serial.println("Save to datastore failed");
				}
			}
		}
	}

	// if the sketch has been running for 5s and the GPS isn't working then give up
	if (millis() > 5000 && gps.charsProcessed() < 10)
	{
		Serial.println("No GPS detected: check wiring then reset.");
		for(;;);
	}

	// allow a manual clear of the database
	if (digitalRead(BTN1) == HIGH){
		Serial.println("Deleting datestore");

		// match all times
		datastore.clear("@gpsreadingtime >= '1900-01-01T00:00:00Z'");
	}
}
