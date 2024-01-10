# Design and development of an embedded system for spatial orientation monitoring
This paper has been written with the aim of measuring and displaying the spatial orientation of a remote controlled car. The data captured by the IMU of Arduino Nano 33 Ble Sense is sent to a smartphone via Bluetooth Low Energy and gets displayed through two different widgets: the first one is a bidimensional inclinometer in which are shown a front and a side view of the RC car animated by roll and pitch, respectively. The second widget consists in a three dimensional view of a .gbl model of an offroad car which rotates in the three dimensional space using the rotation angles of yaw, pitch and roll measured by Arduino Nano.

# Quick start
To setup the embedded system, the following steps need to be followed:

Install Arduino IDE.

Inside the IDE settings, add your board.

Install the following libraries: Arduino_APDS9960, Arduino_LPS22HB, Arduino_HS300x, Arduino_BMI270_BMM150, Arduino_HTS221, Arduino_LSM9DS1, MadgwickAHRS, ArduinoBLE

Upload "Orientation_management.INO" on your Arduino Nano 33 Ble Sense (REV1 or REV2, remember to change the #DEFINE based on the model you are using)

To setup the mobile device, the following steps need to be followed:

Install Visual Studio Code.
Install the Flutter plugin (Flutter SDK 3.10.6)
Now the client application is ready to be debugged on a device.
