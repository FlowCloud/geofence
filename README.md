# Geofence

This project uses the [FlowCloud](http://flow.imgtec.com/developers/) libraries within the Arduino environment on a WiFire development board to create a Internet of Things connected 
Geofence.

Check out the blog for using FlowCloud with Arduino on the WiFire [here](link-not-implemented) or jump straight to the [section for this project](link-not-implemented)

<!-- Image goes here -->

#### Project details

A Bluetooth GPS data logger is used to provide a GPS location over Bluetooth to RS232 module.

The project can be controlled through FlowMessaging and can perform the following actions.

- Fetch the current location of the GPS
- Set a logging period for periodic writes of geolocation data to the Flow DataStore
- Send an alert through FlowMessaging when the GPS is detected to be outside a defined geofence


