import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LocationWeather {
  String city;
  String weatherDescription;

  LocationWeather({required this.city, required this.weatherDescription});

  factory LocationWeather.fromJson(String city, Map<String, dynamic> json) {
    return LocationWeather(
      city: city,
      weatherDescription: json['weather'][0]['description'],
    );
  }

  static Future<LocationWeather> fetch(String city) async {
    final uri = Uri.parse(
        'http://api.openweathermap.org/data/2.5/weather?q=$city&appid=bdf012229187fb28d76b34c868336954');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return LocationWeather.fromJson(city, jsonDecode(response.body));
    } else {
      throw Exception('Failed to load weather data');
    }
  }
}

class WeatherService extends ChangeNotifier {
  List<LocationWeather> _locations = [];

  WeatherService() {
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cityNames = prefs.getStringList('locations') ?? [];
    _locations =
        await Future.wait(cityNames.map(LocationWeather.fetch).toList());
    notifyListeners();
  }

  List<LocationWeather> get locations => _locations;

  Future<void> addLocation(String city) async {
    LocationWeather locationWeather = await LocationWeather.fetch(city);
    _locations.add(locationWeather);
    _saveLocations();
    notifyListeners();
  }

  void removeLocation(int index) {
    _locations.removeAt(index);
    _saveLocations();
    notifyListeners();
  }

  Future<void> _saveLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cityNames =
        _locations.map((location) => location.city).toList();
    prefs.setStringList('locations', cityNames);
  }
}

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => WeatherService(),
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatelessWidget {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
      ),
      body: Consumer<WeatherService>(
        builder: (context, weatherService, child) {
          return ListView.builder(
            itemCount: weatherService.locations.length,
            itemBuilder: (context, index) {
              LocationWeather locationWeather = weatherService.locations[index];
              return ListTile(
                title: Text(locationWeather.city),
                subtitle: Text(locationWeather.weatherDescription),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => weatherService.removeLocation(index),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Add a new location'),
              content: TextField(
                controller: _controller,
                decoration: InputDecoration(hintText: 'Enter city name'),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('ADD'),
                  onPressed: () {
                    Provider.of<WeatherService>(context, listen: false)
                        .addLocation(_controller.text);
                    _controller.clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
