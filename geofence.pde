#include <TinyGPS++.h>

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

// The GPS module we will be using uses a 9600-baud RS232 connection
#define GPSBaud (9600)

// Object for the tinyGPS++ library we are using
TinyGPSPlus gps;

void setup()
{
	// use the same baud rate as the boot console so that we don't have to change the
	// serial connection baud rate
	Serial.begin(115200);

	// We are not reading from Serial and don't mind sharing it with libappbase
	g_EnableConsole = true;
	g_EnableConsoleInput = true;

	Serial.println("RS232_GPS.ino  ");

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

	Serial.println();
	Serial.println();
}

void logLocation()
{
	Serial.print("latitude: ");
	Serial.println(gps.location.lat());
	Serial.print("longitude: ");
	Serial.println(gps.location.lng());
	Serial.print("reading age: ");
	Serial.println(gps.location.age());

	Serial.print("satellites: ");
	Serial.println(gps.satellites.value());

	Serial.print("altitude: ");
	Serial.println(gps.altitude.meters());

	Serial.print("speed: ");
	Serial.println(gps.speed.mps());

	Serial.print("course: ");
	Serial.println(gps.course.deg());

	Serial.print("hdop: ");
	Serial.println(gps.hdop.value());

	Serial.println();
	Serial.println();
}

void loop()
{
	// log every 5 seconds
	#define LOGGING_PERIOD 5000
	static long lastLog = -2*LOGGING_PERIOD;

	while (Serial2.available() > 0)
	{
		if (gps.encode(Serial2.read()))
		{

			// if the configured period of time has passed then save a new reading
			if (millis() - lastLog > LOGGING_PERIOD)
			{
				lastLog = millis();

				logLocation();
			}
		}
	}

	// if the sketch has been running for 5s and the GPS isn't working then give up
	if (millis() > 5000 && gps.charsProcessed() < 10)
	{
		Serial.println("No GPS detected: check wiring then reset.");
		for(;;);
	}

}
