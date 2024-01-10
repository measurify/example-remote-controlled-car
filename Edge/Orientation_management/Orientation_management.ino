#define NANO_V1 //NANO_V2

#include <Arduino_APDS9960.h>
#include <Arduino_LPS22HB.h>

#ifdef NANO_V1
#include <Arduino_HTS221.h>
#include <Arduino_LSM9DS1.h>
#endif

#ifdef NANO_V2
#include <Arduino_HS300x.h>
#include <Arduino_BMI270_BMM150.h>
#endif 

#include <MadgwickAHRS.h>
#include <ArduinoBLE.h>

#define ACC_MULTIPLIER 8192
#define GYR_MULTIPLIER 16.384
#define MAG_MULTIPLIER 81.92
#define TEMP_MULTIPLIER 100
#define HUM_MULTIPLIER 100
#define PRES_MULTIPLIER 100
#define gscale 1


String name = "Mesurify-Meter";

Madgwick filter;

const char* service_uuid = "8e7c2dae-0000-4b0d-b516-f525649c49ca";
const char* sampling_period_uuid = "8e7c2dae-0001-4b0d-b516-f525649c49ca";
const char* imu_uuid = "8e7c2dae-0002-4b0d-b516-f525649c49ca";
const char* environment_uuid = "8e7c2dae-0003-4b0d-b516-f525649c49ca";
const char* orientation_uuid = "8e7c2dae-0004-4b0d-b516-f525649c49ca";

BLEService service(service_uuid);

// Loop delay
int sampling_period = 250;
int heartbit_period = 5000;
unsigned long sampling_previousMillis = 0;
unsigned long heartbit_previousMillis = 0;
BLECharacteristic samplingPeriodCharacteristic(sampling_period_uuid,  BLEWrite | BLERead, sizeof(int));

// IMU: 9 ints G, degress per second, uT (G*8192,degrees per second*16.384,uT*81.92)
float acceleration[3];
float angular_speed[3];
float magnetic_field[3];
BLECharacteristic imuCharacteristic(imu_uuid, BLENotify, 9 * sizeof(int16_t)); 

// Environment: proximity, temperature, humidity, pressure, light, r, g, b  
int16_t proximityInt16;
int16_t temperatureInt16;
int16_t humidityInt16;
int16_t pressureInt16;
int light;
int red, green, blue;
int16_t lightInt16;
int16_t redInt16, greenInt16, blueInt16;
BLECharacteristic environmentCharacteristic(environment_uuid, BLENotify, 8 * sizeof(int16_t));

// Orientation: 3 floats degress
float heading;
float pitch;
float roll;
BLECharacteristic orientationCharacteristic(orientation_uuid, BLENotify, 3 * sizeof(float)); 

void init_sensors(void){
  while(!APDS.begin()) { Serial.println("Error, APDS"); delay(500); };

  #ifdef NANO_V1
  while(!HTS.begin()) { Serial.println("Error, HTS"); delay(500); };
  #endif
  
  #ifdef NANO_V2
  while(!HS300x.begin()) { Serial.println("Error, HTS"); delay(500); };
  #endif
  
  while(!BARO.begin()) { Serial.println("Error, BARO"); delay(500); };
  while(!IMU.begin()) { Serial.println("Error, IMU"); delay(500); };
}

void init_BLE(){
  while(!BLE.begin()) { Serial.println("Error, BLE"); delay(500); };

  String address = BLE.address();

  BLE.setLocalName(name.c_str());
  BLE.setDeviceName(name.c_str());
  BLE.setAdvertisedService(service); 
   
  service.addCharacteristic(imuCharacteristic);
  service.addCharacteristic(environmentCharacteristic);
  service.addCharacteristic(orientationCharacteristic);

  samplingPeriodCharacteristic.setEventHandler(BLEWritten, onSamplingPeriodCharacteristicWrite);
  service.addCharacteristic(samplingPeriodCharacteristic);
  
  BLE.addService(service);
  BLE.advertise();
}
void initFilter(){
  filter.begin(1000/sampling_period);
}

void setup() {
  Serial.begin(9600);

  Serial.println("Init sensors...");  
  init_sensors();
  
  Serial.println("Init BLE...");  
  init_BLE();

  Serial.println("Init Filter...");  
  initFilter();

  Serial.println("Start loop...");  

  //Accelerometer setup
  IMU.setAccelFS(2); //full scale setting
  IMU.setAccelODR(5); //ODR: output data rate measured in Hz
  IMU.setAccelOffset(-0.013457, -0.007203, -0.012840);
  IMU.setAccelSlope (1.001740, 0.996517, 0.999404);
  //Gyrsoscope setup
  IMU.gyroUnit = DEGREEPERSECOND;
  IMU.setGyroFS(3);
  IMU.setGyroODR(5);
  IMU.setGyroOffset (-1.489929, -0.464600, 0.043884);
  IMU.setGyroSlope (1.243725, 1.144730, 1.074688);
  //Mangetometer setup
  IMU.setMagnetFS(0);
  IMU.setMagnetODR(5);
  IMU.setMagnetOffset(7.622681, 32.914429, 156.889038);
  IMU.setMagnetSlope (2.323434, 1.434650, 1.358518);

  Serial.println("Gyro setting ");  
  Serial.print("Gyroscope FS= ");    
  Serial.print(IMU.getGyroFS());
  Serial.print("Gyroscope ODR=");  
  Serial.println(IMU.getGyroODR());
  Serial.print("Gyro unit=");           
  Serial.println(IMU.gyroUnit);

  // The slowest ODR determines the sensor rate, Accel and Gyro share their ODR
  float sensorRate = min(IMU.getGyroODR(),IMU.getMagnetODR());
  // start the filter to run at the sample rate:
  filter.begin(sensorRate);
}

void manageRawValues() {
  if (IMU.accelerationAvailable()) {
    float xAcc, yAcc, zAcc;
    IMU.readAcceleration(xAcc, yAcc, zAcc);
    acceleration[0] = xAcc;
    acceleration[1] = yAcc;
    acceleration[2] = zAcc;
  }
  
  if (IMU.gyroscopeAvailable()) {
    float xGyro, yGyro, zGyro;
    IMU.readGyroscope(xGyro, yGyro, zGyro);
    angular_speed[0] = xGyro;
    angular_speed[1] = yGyro;
    angular_speed[2] = zGyro;
  }

  if (IMU.magneticFieldAvailable()) {
    float xMag, yMag, zMag;
    IMU.readMagneticField(xMag, yMag, zMag);
    magnetic_field[0] = xMag;
    magnetic_field[1] = yMag;
    magnetic_field[2] = zMag;
  }
}

void manageIMU() {
  int16_t imu[9] = { (int16_t)round(acceleration[0]*ACC_MULTIPLIER), (int16_t)round(acceleration[1]*ACC_MULTIPLIER), (int16_t)round(acceleration[2]*ACC_MULTIPLIER), 
                   (int16_t)round(angular_speed[0]*GYR_MULTIPLIER), (int16_t)round(angular_speed[1]*GYR_MULTIPLIER), (int16_t)round(angular_speed[2]*GYR_MULTIPLIER),
                   (int16_t)round(magnetic_field[0]*MAG_MULTIPLIER), (int16_t)round(magnetic_field[1]*MAG_MULTIPLIER), (int16_t)round(magnetic_field[2]*MAG_MULTIPLIER) 
                 };
  imuCharacteristic.writeValue(imu, sizeof(imu));
} 

void manageOrientation(){
  filter.update(angular_speed[0], angular_speed[1], angular_speed[2],
                acceleration[0], acceleration[1], acceleration[2],
                magnetic_field[0], magnetic_field[1], magnetic_field[2]);

  heading = filter.getYawRadians();
  pitch = filter.getRollRadians();
  roll = filter.getPitchRadians();

  float orientation[3] = { heading, pitch, roll };
  orientationCharacteristic.writeValue(orientation, sizeof(orientation));
}

void manageEnvironment() {
  if (APDS.proximityAvailable()) { proximityInt16 = (int16_t)round(APDS.readProximity()); }
  
  #ifdef NANO_V1
  temperatureInt16 = (int16_t)round(HTS.readTemperature()*TEMP_MULTIPLIER); 
  humidityInt16 = (int16_t)round(HTS.readHumidity()*HUM_MULTIPLIER); 
  #endif

  #ifdef NANO_V2
  temperatureInt16 = (int16_t)round(HS300x.readTemperature()*TEMP_MULTIPLIER);
  humidityInt16 = (int16_t)round(HS300x.readHumidity()*HUM_MULTIPLIER);
  #endif

  pressureInt16 = (int16_t)round(BARO.readPressure()*PRES_MULTIPLIER);
  if (APDS.colorAvailable()) { APDS.readColor(red, green, blue, light); 
    redInt16 = (int16_t)round(red);
    greenInt16 = (int16_t)round(green);
    blueInt16 = (int16_t)round(blue);
    lightInt16 = (int16_t)round(light);
   }

  int16_t environment[8] = { proximityInt16, temperatureInt16, humidityInt16, pressureInt16, lightInt16, redInt16, greenInt16, blueInt16 };
  environmentCharacteristic.writeValue(environment, sizeof(environment));
} 

void onSamplingPeriodCharacteristicWrite(BLEDevice central, BLECharacteristic characteristic) {
  sampling_period = word(samplingPeriodCharacteristic[0], samplingPeriodCharacteristic[1]);
  Serial.print("Sampling period change: "); 
  Serial.print(sampling_period);
  Serial.println(" ms"); 
}

void heartbit() {
  if (millis() - heartbit_previousMillis >= heartbit_period) {
      if (BLE.connected()) {
        Serial.print("BLE client connected (");
        Serial.print(BLE.address());
        Serial.println(")...");
        Serial.print(" - Sampling period: ");
        Serial.println(sampling_period);
        if (imuCharacteristic.subscribed()) Serial.println(" - IMU subscribed");
        if (environmentCharacteristic.subscribed()) Serial.println(" - Environment subscribed");
        if (orientationCharacteristic.subscribed()) Serial.println(" - Orientation subscribed");
      }
      else {
        Serial.println("No BLE client connected...");
      }
      heartbit_previousMillis = millis();
    }
}

void loop() {
  heartbit();
  if (BLE.connected()) {
    if (millis() - sampling_previousMillis >= sampling_period) {
      if (imuCharacteristic.subscribed() || orientationCharacteristic.subscribed()) { manageRawValues(); }
      if (imuCharacteristic.subscribed()) { manageIMU(); }
      if (environmentCharacteristic.subscribed()) { manageEnvironment(); }
      if (orientationCharacteristic.subscribed()) { manageOrientation(); }
      sampling_previousMillis = millis();
    }
  } 
}