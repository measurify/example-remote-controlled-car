import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quick_blue/quick_blue.dart';
import 'globals.dart';
//import 'default.dart';
import 'dart:typed_data';

class inclinometer extends StatefulWidget {
  final Globals globals;
  //final Function toggleCollecting;
  //final Function checkMeasureExist;
  //final Function sendData;
  //final String selectedOption1;
  //final String selectedOption2;
  final String title = 'Inclinometer';

  inclinometer({
    required this.globals,
    //required this.toggleCollecting,
    //required this.checkMeasureExist,
    //required this.sendData,
    //required this.selectedOption1,
    //required this.selectedOption2,
  });

  @override
  inclinometerState createState() => inclinometerState();
}

@override
inclinometerState createState() => inclinometerState();

class inclinometerState extends State<inclinometer> {
  //const inclinometerState({super.key, required this.title});
  double _rx1 = 0.0, _ry1 = 0.0, _rz1 = 0.0;
  double _rx2 = 0.0, _ry2 = 0.0, _rz2 = 0.0;
  bool isRunning = false;

  @override
  void initState() {
    loadConfigVariables();
    QuickBlue.setValueHandler(_handleValueChange);
  }

  @override
  void dispose() {
    super.dispose();
    QuickBlue.setValueHandler(null);
  }

  // Retrieve configuration variables from SharedPreferences
  Future<void> loadConfigVariables() async {
    widget.globals.isCollecting =
        widget.globals.prefs.getBool('isCollecting') ?? defaults.isCollecting;
    widget.globals.option1 =
        widget.globals.prefs.getBool('option1') ?? defaults.option1;
    widget.globals.option2 =
        widget.globals.prefs.getBool('option2') ?? defaults.option2;
    //widget.globals.option3 =
    //widget.globals.prefs.getBool('option3') ?? defaults.option3;
    widget.globals.measureName =
        widget.globals.prefs.getString('measureName') ?? defaults.measureName;
    widget.globals.savedValue =
        widget.globals.prefs.getInt('savedValue') ?? defaults.savedValue;
    widget.globals.url = widget.globals.prefs.getString('url') ?? defaults.url;
    widget.globals.tenantId =
        widget.globals.prefs.getString('tenantId') ?? defaults.tenantId;
    widget.globals.deviceToken =
        widget.globals.prefs.getString('deviceToken') ?? defaults.deviceToken;
    widget.globals.bleServiceId =
        widget.globals.prefs.getString('bleServiceId') ?? defaults.bleServiceId;
    widget.globals.thingName =
        widget.globals.prefs.getString('thingName') ?? defaults.thingName;
    widget.globals.deviceName =
        widget.globals.prefs.getString('deviceName') ?? defaults.deviceName;
    widget.globals.imuCharacteristicId =
        widget.globals.prefs.getString('imuCharacteristicId') ??
            defaults.imuCharacteristicId;
    widget.globals.envCharacteristicId =
        widget.globals.prefs.getString('envCharacteristicId') ??
            defaults.envCharacteristicId;
    widget.globals.orientationCharacteristicId =
        widget.globals.prefs.getString('orientationCharacteristicId') ??
            defaults.orientationCharacteristicId;
    widget.globals.oriValues = List<double>.filled(3, 0.0);
    widget.globals.oriValues[0] = 0.0;
    widget.globals.oriValues[1] = 0.0;
    widget.globals.oriValues[2] = 0.0;
  }

  //When a characteristic change he read the value and decode it and save into different variables
  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    if (this.mounted) {
      if (characteristicId == "8e7c2dae-0002-4b0d-b516-f525649c49ca") {
        //IMU
        Map<String, dynamic> jsonObj = parseIMUData(value, 9);
        setState(() {
          // Add the parsed data to the receivedValues list of the specific characteristic
          widget.globals.receivedIMUJsonValues.add(jsonObj);
        });
      }

      if (characteristicId == "8e7c2dae-0004-4b0d-b516-f525649c49ca") {
        //ORI
        Map<String, dynamic> jsonObj = parseORIData(value, 3);
        double pitch = jsonObj["values"][1];
        double roll = jsonObj["values"][2];
        setState(() {
          _rz1 = roll;
          _rz2 = -pitch;
        });
      }

      if (characteristicId == "8e7c2dae-0003-4b0d-b516-f525649c49ca") {
        //ENV
        Map<String, dynamic> jsonObj = parseENVData(value, 8);
        setState(() {
          widget.globals.receivedENVJsonValues.add(jsonObj);
        });
      }
      setState(() {
        widget.globals.savedValue++;
      });
    }
  }

  //convert the IMU data 9 int16 array back to float and create the json object ready to be sended
  Map<String, dynamic> parseIMUData(Uint8List value, int ArrayLength) {
    final byteData = ByteData.view(value.buffer);
    final imuData = List<int>.filled(ArrayLength, 0);
    List<double> floatValues = List<double>.filled(9, 0.0);
    for (var i = 0; i < imuData.length; i++) {
      if (i < value.lengthInBytes ~/ 2) {
        int intValue = byteData.getInt16(i * 2, Endian.little);
        imuData[i] = intValue;
        print("intValue:" + intValue.toString());
      }
    }
    for (int i = 0; i < imuData.length; i++) {
      //conversion IMU from int to float
      if (i < 3) {
        floatValues[i] = imuData[i] / 8192;
      } else if (i < 6) {
        floatValues[i] = imuData[i] / 16.384;
      } else {
        floatValues[i] = imuData[i] / 81.92;
      }
    }
    Map<String, dynamic> jsonObj = {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "values": floatValues,
    };
    return jsonObj;
  }

  Map<String, dynamic> parseORIData(Uint8List value, int ArrayLength) {
    final byteData = ByteData.view(value.buffer);
    List<double> oriValues = List<double>.filled(3, 0.0);
    oriValues[0] = byteData.getFloat32(0, Endian.little);
    oriValues[1] = byteData.getFloat32(4, Endian.little);
    oriValues[2] = byteData.getFloat32(8, Endian.little);
    print(oriValues);

    Map<String, dynamic> jsonObj = {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "values": oriValues,
    };
    return jsonObj;
  }

  Map<String, dynamic> parseENVData(Uint8List value, int ArrayLength) {
    final byteData = ByteData.view(value.buffer);
    final envData = List<int>.filled(ArrayLength, 0);
    List<double> floatValues = List<double>.filled(8, 0.0);
    for (var i = 0; i < envData.length; i++) {
      if (i < value.lengthInBytes ~/ 2) {
        int intValue = byteData.getInt16(i * 2, Endian.little);
        envData[i] = intValue;
        print("intValue:" + intValue.toString());
      }
    }

    for (int i = 0; i < envData.length; i++) {
      //proximity data
      if (i < 1) {
        floatValues[i] = envData[i].toDouble();
      } else {
        switch (i) {
          //temperature
          case 1:
            floatValues[i] = envData[i] / 100;
            break;
          //humidity
          case 2:
            floatValues[i] = envData[i] / 100;
            break;
          //pressure
          case 3:
            floatValues[i] = envData[i] / 100;
            break;
          //light
          case 4:
            floatValues[i] = envData[i].toDouble();
            break;
          //red
          case 5:
            floatValues[i] = envData[i].toDouble();
            break;
          //green
          case 6:
            floatValues[i] = envData[i].toDouble();
            break;
          //blue
          case 7:
            floatValues[i] = envData[i].toDouble();
            break;
          default:
            floatValues[i] = 0.0;
        }
      }
    }

    Map<String, dynamic> jsonObj = {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "values": floatValues,
    };

    return jsonObj;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform(
              transform: Matrix4.identity()
                ..translate(0.0, 0.0, 0.0)
                ..rotateX(_rx1)
                ..rotateY(_ry1)
                ..rotateZ(_rz1),
              alignment: Alignment.center,
              child: Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 16.0),
                  child: Cube1(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Transform(
              transform: Matrix4.identity()
                ..translate(0.0, 0.0, 0.0)
                ..rotateX(_rx2)
                ..rotateY(_ry2)
                ..rotateZ(_rz2),
              alignment: Alignment.center,
              child: Center(
                child: Cube2(),
              ),
            ),
            const SizedBox(height: 32),
            /*Slider(
      value: _rz1,
      min: pi * -2,
      max: pi * 2,
      onChanged: (value) => setState(() {
        _rz1 = value;
        _rz2 = value;
      }),
    ),*/
            ElevatedButton(
              onPressed: () {
                setState(() {
                  print("Button pressed");
                  isRunning = !isRunning;
                  //log the value of isRunning
                  print('isRunning: ${isRunning ? 'true' : 'false'}');
                });
                if (isRunning) {
                  startAction();
                } else {
                  stopAction();
                }
              },
              child: Text(isRunning ? 'Stop' : 'Start'),
            ),
            /*ElevatedButton(
      onPressed: () {
        setState(() {
          _rz1 = (pi * -2) + (Random().nextDouble() * (pi * 4));
          _rz2 = (pi * -2) + (Random().nextDouble() * (pi * 4));
        });
        // Define the action to be taken when the button is pressed.
      },
      child: Text("Test rotation"),
    ),*/
          ],
        ),
      ),
    );
  }

  void startAction() async {
    print("Started!");

    /*if (!widget.globals.option3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select ORI option to proceed')),
      );
    } else {*/
      //widget.toggleCollecting();
      //print('opzione');
      if (!widget.globals.isCollecting) {
        //print('opzione3');
        print(widget.globals.deviceId);
        print(widget.globals.bleServiceId);
        print(widget.globals.orientationCharacteristicId);
        QuickBlue.setNotifiable(
          widget.globals.deviceId,
          widget.globals.bleServiceId,
          widget.globals.orientationCharacteristicId,
          BleInputProperty.notification,
        );
      //print("animazione partita");
      } else {
        QuickBlue.setNotifiable(
          widget.globals.deviceId,
          widget.globals.bleServiceId,
          widget.globals.orientationCharacteristicId,
          BleInputProperty.disabled,
        );
      //}
    }
  }

  void stopAction() {
    print("Stopped!");
    setState(() {
      isRunning = false;
    });
  }
}


class Cube1 extends StatelessWidget {
  const Cube1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // FRONT
        Transform(
          transform: Matrix4.identity()..translate(0.0, 0.0, -100.0),
          child: Container(
            color: Colors.white,
            child: Image.asset(
              'assets/front_square_200px.png',
              width: 200,
              height: 200,
            ),
          ),
        ),
        /*
        // BACK
        Transform( 
          transform: Matrix4.identity()
            ..translate(0.0, 0.0, 50.0),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),
        
        // PORT
        Transform( 
          transform: Matrix4.identity()
            ..translate(-50.0, 0.0, 0.0)
            ..rotateY(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // STARBOARD
        Transform( 
          transform: Matrix4.identity()
            ..translate(50.0, 0.0, 0.0)
            ..rotateY(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // TOP
        Transform(
          transform: Matrix4.identity()
            ..translate(0.0, -50.0, 0.0)
            ..rotateX(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // BOTTOM
        Transform(
          transform: Matrix4.identity()
            ..translate(0.0, 50.0, 0.0)
            ..rotateX(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),*/
      ],
    );
  }
}

class Cube2 extends StatelessWidget {
  const Cube2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // FRONT
        Transform(
          transform: Matrix4.identity()..translate(0.0, 0.0, -100.0),
          child: Container(
            color: Colors.white,
            child: Image.asset(
              'assets/left_side_square_200px.png',
              width: 200,
              height: 200,
            ),
          ),
        ),
        /*
        // BACK
        Transform( 
          transform: Matrix4.identity()
            ..translate(0.0, 0.0, 50.0),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),
        
        // PORT
        Transform( 
          transform: Matrix4.identity()
            ..translate(-50.0, 0.0, 0.0)
            ..rotateY(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // STARBOARD
        Transform( 
          transform: Matrix4.identity()
            ..translate(50.0, 0.0, 0.0)
            ..rotateY(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // TOP
        Transform(
          transform: Matrix4.identity()
            ..translate(0.0, -50.0, 0.0)
            ..rotateX(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),

        // BOTTOM
        Transform(
          transform: Matrix4.identity()
            ..translate(0.0, 50.0, 0.0)
            ..rotateX(-pi/2),
          alignment: Alignment.center,
          child: Image.asset(
              'assets/transparent_square.png',
              width: 100,
              height: 100,
            ),
        ),*/
      ],
    );
  }
}
