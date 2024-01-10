import 'package:flutter/material.dart';
import 'package:babylonjs_viewer/babylonjs_viewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'globals.dart';
import 'dart:typed_data';
import 'package:quick_blue/quick_blue.dart';

class Visualization3DPage extends StatefulWidget {
  final Globals globals;

  Visualization3DPage({required this.globals});

  @override
  _Visualization3DPageState createState() => _Visualization3DPageState();
}

@override
_Visualization3DPageState createState() => _Visualization3DPageState();

class _Visualization3DPageState extends State<Visualization3DPage> {
  WebViewController? _controller;
  bool isRunning = false;
  double _yaw = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;

  @override
  void initState() {
    super.initState();
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
        double yaw = jsonObj["values"][0];
        double pitch = jsonObj["values"][1];
        double roll = jsonObj["values"][2];
        //pitch from sensor is [-pi,pi]
        //if pitch is negative add pi
        /*if(pitch < 0){
        pitch += 2*pi;
      }
      if(roll < 0){
        roll += 2*pi;
      }*/
        //converting pitch value in range [0,1] for rotationTransition
        //pitch /= 2*pi;
        //roll /= 2*pi;
        print(yaw);
        print(pitch);
        print(roll);
        setState(() {
          _roll = roll;
          _pitch = -pitch;
          _yaw = yaw;
          _controller!.runJavascript('rotateImage($_yaw, $_pitch, $_roll)');
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
    //To visualize jsonObj
    //String jsonDataString = jsonEncode(jsonObj);
    //print(jsonDataString);
    //print(floatValues);
    return jsonObj;
  }

  Map<String, dynamic> parseORIData(Uint8List value, int ArrayLength) {
    final byteData = ByteData.view(value.buffer);
    List<double> oriValues = List<double>.filled(3, 0.0);
    oriValues[0] = byteData.getFloat32(0, Endian.little);
    oriValues[1] = byteData.getFloat32(4, Endian.little);
    oriValues[2] = byteData.getFloat32(8, Endian.little);
    print(oriValues);
    print('prova');

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
    return Scaffold(
      body: Transform(
        transform: Matrix4.identity(),
        child: BabylonJSViewer(
          functions: '''
                        
                        function toggleAutoRotate(texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                          viewer.sceneManager.camera.useAutoRotationBehavior = !viewer.sceneManager.camera.useAutoRotationBehavior
                            }


                          function movePosition(texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                                                    
                          let scene = viewer.sceneManager.scene; // Ottieni l'oggetto della scena

                          let meshesInScene = scene.meshes; // Ottieni una lista di tutte le mesh nella scena
                          let mesh; 
                          for (let i = 0; i < meshesInScene.length; i++) {                            
                            if(meshesInScene[i].name == 'pivotMesh'){
                              console.log("Found mesh")
                              mesh = meshesInScene[i];
                              meshesInScene=null;
                              break;
                            }
                          }              
                          let x = mesh.position.x; 
                          let y = mesh.position.y;
                          let z = mesh.position.z;                          
                          console.log(x);
                          console.log(y);
                          console.log(z);
                          console.log(mesh.getPivotPoint().toString());
                          x=0.1;
                          
                          mesh.position.x += 0.5;
                          //mesh.rotation.y += 2;
                          //mesh.rotation.z += 2;
                      }

                        function rotateImage90DegreesX(texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                                                    
                          let scene = viewer.sceneManager.scene; // Ottieni l'oggetto della scena

                          let meshesInScene = scene.meshes; // Ottieni una lista di tutte le mesh nella scena
                          let mesh; 
                          for (let i = 0; i < meshesInScene.length; i++) {                            
                            if(meshesInScene[i].name == 'pivotMesh'){
                              console.log("Found mesh")
                              mesh = meshesInScene[i];
                              meshesInScene=null;
                              break;
                            }
                          }   
                          mesh.rotation.x += 0.5;
                      }function rotateImage90DegreesY(texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                                                    
                          let scene = viewer.sceneManager.scene; // Ottieni l'oggetto della scena

                          let meshesInScene = scene.meshes; // Ottieni una lista di tutte le mesh nella scena
                          let mesh; 
                          for (let i = 0; i < meshesInScene.length; i++) {                            
                            if(meshesInScene[i].name == 'pivotMesh'){
                              console.log("Found mesh")
                              mesh = meshesInScene[i];
                              meshesInScene=null;
                              break;
                            }
                          }   
                          mesh.rotation.y += 0.5;
                      }
                      function rotateImage90DegreesZ(texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                                                    
                          let scene = viewer.sceneManager.scene; // Ottieni l'oggetto della scena

                          let meshesInScene = scene.meshes; // Ottieni una lista di tutte le mesh nella scena
                          let mesh; 
                          for (let i = 0; i < meshesInScene.length; i++) {                            
                            if(meshesInScene[i].name == 'pivotMesh'){
                              console.log("Found mesh")
                              mesh = meshesInScene[i];
                              meshesInScene=null;
                              break;
                            }
                          }   
                          mesh.rotation.z += 0.5;
                      } 
                      function rotateImage(yaw, pitch, roll, texture) {
                          let viewer = BabylonViewer.viewerManager.getViewerById('viewer-id');
                                                    
                          let scene = viewer.sceneManager.scene; // Ottieni l'oggetto della scena

                          let meshesInScene = scene.meshes; // Ottieni una lista di tutte le mesh nella scena
                          let mesh; 
                          for (let i = 0; i < meshesInScene.length; i++) {                            
                            if(meshesInScene[i].name == 'pivotMesh'){
                              console.log("Found mesh")
                              mesh = meshesInScene[i];
                              meshesInScene=null;
                              break;
                            }
                          }
                          console.log("ciccio");   
                          console.log(yaw);
                          console.log(pitch);
                          console.log(roll);
                          mesh.rotation.x = pitch;
                          mesh.rotation.y = -yaw;
                          mesh.rotation.z = -roll;
                      }        
                      ''',
          controller: (WebViewController controller) {
            _controller = controller;
          },
          src: 'assets/car.glb',
        ),
      ),
      floatingActionButton: Row(
        children: [
          SizedBox(width: 32),
          FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('toggleAutoRotate()');
            },
            child: Icon(Icons.pause),
          ),
          SizedBox(width: 16),
          /*FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('movePosition()');
            },
            child: Icon(Icons.rotate_right),
          ),
          SizedBox(width: 16),*/
          /*FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('rotateImage90DegreesX()');
            },
            child: Icon(Icons.rotate_right),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('rotateImage90DegreesY()');
            },
            child: Icon(Icons.rotate_right),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('rotateImage90DegreesZ()');
            },
            child: Icon(Icons.rotate_right),
          ),*/
          /*FloatingActionButton(
            onPressed: () {
              _controller!.runJavascript('rotateImage($_yaw, $_pitch, $_roll)');
            },
            child: Icon(Icons
                .rotate_right), // Sostituisci 'second_icon' con l'icona desiderata
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
        ],
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
