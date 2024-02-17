import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  String selectedVehicle = 'car'; // Default vehicle
  TextEditingController addressController = TextEditingController();
  List<String> addresses = [];
  StreamController<Position> _locationStreamController = StreamController<Position>();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    Geolocator.getPositionStream().listen((Position position) {
      _locationStreamController.add(position);
    });
  }

  @override
  void dispose() {
    _locationStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Maps Route with Stops'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      hintText: 'Enter an address',
                    ),
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () {
                    _addAddressToList(addressController.text);
                    addressController.clear();
                  },
                  child: Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(addresses[index]),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle),
                    onPressed: () {
                      _removeAddressFromList(index);
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _handleAddressInput();
            },
            child: Text('OK'),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                setState(() {
                  mapController = controller;
                });
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(0.0, 0.0),
                zoom: 14.0,
              ),
              myLocationEnabled: true,
              markers: markers,
              polylines: polylines,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _handleAddressInput();
        },
        child: Icon(Icons.directions),
      ),
    );
  }

  void _addAddressToList(String address) {
    setState(() {
      addresses.add(address);
    });
  }

  void _removeAddressFromList(int index) {
    setState(() {
      addresses.removeAt(index);
    });
  }

  void _handleAddressInput() async {
    List<LatLng> waypoints = [];
    Map<String, double?> currentLocation = await _getCurrentLocation();
    LatLng userLocation = LatLng(currentLocation['latitude']!, currentLocation['longitude']!);

    List<Map<String, dynamic>> distances = [];
    for (String address in addresses) {
      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          double distance = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            locations[0].latitude!,
            locations[0].longitude!,
          );
          distances.add({'address': address, 'distance': distance});
        } else {
          print("No location found for address: $address");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error'),
                content: Text('Failed to parse one or more addresses.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
          return;
        }
      } catch (e) {
        print("Error parsing address: $e");
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('Failed to parse one or more addresses.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }
    }

    distances.sort((a, b) => a['distance'].compareTo(b['distance']));

    for (var entry in distances) {
      String address = entry['address'];
      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          waypoints.add(LatLng(locations[0].latitude!, locations[0].longitude!));
        } else {
          print("No location found for address: $address");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error'),
                content: Text('Failed to parse one or more addresses.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
          return;
        }
      } catch (e) {
        print("Error parsing address: $e");
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('Failed to parse one or more addresses.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }
    }

    waypoints.insert(0, userLocation);
    await _getRouteWithStops(waypoints, distances);
  }

  Future<void> _getRouteWithStops(List<LatLng> waypoints, List<Map<String, dynamic>> distances) async {
    List<LatLng> polylineCoordinates = [];

    for (int i = 0; i < waypoints.length - 1; i++) {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyBcfwu-Rj73Gr9dvOvN_rCMmGDn-Mmp024',
        PointLatLng(waypoints[i].latitude, waypoints[i].longitude),
        PointLatLng(waypoints[i + 1].latitude, waypoints[i + 1].longitude),
        travelMode: selectedVehicle == 'bike' ? TravelMode.bicycling : TravelMode.driving,
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }
    }

    setState(() {
      polylines.clear();
      markers.clear();
    });

    setState(() {
      polylines.add(Polyline(
        polylineId: PolylineId('route'),
        color: Colors.blue,
        points: polylineCoordinates,
      ));
    });

    for (int i = 0; i < waypoints.length; i++) {
      String stopName;
      String stopAddress;

      if (i == 0) {
        stopName = 'User Location';
        stopAddress = 'User Location';
      } else {
        stopName = distances[i - 1]['address'];
        stopAddress = addresses[i - 1];
      }

      String stopSnippet = (i == 0) ? 'User Location' : 'Stop $i';

      markers.add(Marker(
        markerId: MarkerId(stopName),
        position: waypoints[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: stopName,
          snippet: stopSnippet,
        ),
      ));
    }

    if (polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds = LatLngBounds(
        southwest: polylineCoordinates.first,
        northeast: polylineCoordinates.last,
      );
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
    }
  }

  Future<Map<String, double?>> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print("Error getting user location: $e");
      return {'latitude': 0.0, 'longitude': 0.0};
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      await _requestLocationPermission();
    } else if (permission == LocationPermission.deniedForever) {
      // Handle case where user denied permission permanently
    } else {
      _centerOnUserLocation();
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.deniedForever) {
      // Handle case where user denied permission permanently
    } else {
      _centerOnUserLocation();
    }
  }

  void _centerOnUserLocation() async {
    Map<String, double?> currentLocation = await _getCurrentLocation();
    LatLng userLocation = LatLng(currentLocation['latitude']!, currentLocation['longitude']!);

    mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLocation, 14.0));
  }
}

