import 'dart:async';

import 'package:association_official_app/official/vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/bloc/sem_cache.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';

class TaxiOperations extends StatefulWidget {
  const TaxiOperations(
      {super.key, required this.vehicle, this.startDate, this.endDate});

  final lib.Vehicle vehicle;
  final String? startDate, endDate;

  @override
  TaxiOperationsState createState() => TaxiOperationsState();
}

class TaxiOperationsState extends State<TaxiOperations>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final mm = '🍅🍅🍅🍅TaxiOperations 🍐🍅🍐';
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  lib.VehicleData? vehicleData;

  // late StreamSubscription<lib.LocationResponse> respSub;
  late StreamSubscription<lib.VehicleTelemetry> telemetryStreamSub;
  late FCMService fcmService = GetIt.instance<FCMService>();
  SemCache semCache = GetIt.instance<SemCache>();
  int hours = 24;
  bool busy = false;
  String title = "TaxiOperations ";
  String? startDate, endDate;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getVehicleData();
  }

  Future _getVehicleData() async {
    pp('$mm ... _getVehicleData that shows the last ${E.blueDot} $hours hours .... ');
    if (widget.startDate == null) {
      var now = DateTime.now().subtract(const Duration(hours: 24));
      startDate =
          DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
    } else {
      var now = DateTime.parse(widget.startDate!);
      startDate =
          DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
    }

    if (widget.endDate == null) {
      var end = DateTime.now();
      endDate =
          DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();
    } else {
      var end = DateTime.parse(widget.endDate!);
      endDate =
          DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();
    }

    final sd = DateTime.parse(startDate!).toUtc().toIso8601String();
    final ed = DateTime.parse(endDate!).toUtc().toIso8601String();

    setState(() {
      busy = true;
    });
    try {
      vehicleData = await listApiDog.getVehicleData(
          vehicleId: widget.vehicle.vehicleId!, startDate: sd, endDate: ed);
      if (mounted) {
        if (vehicleData != null) {
          /// telemetry = vehicleData!.vehicleTelemetry;
        }
      }
    } catch (e, stack) {
      pp('$e - $stack');
      if (mounted) {
        showSnackBar(
            backgroundColor: Colors.red,
            message: 'Could not get data for you. Please try again',
            context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double totalCommuterCash = 0.00;
  double totalRankFeeCash = 0.00;
  int totalPassengers = 0;

  void _setTotals() {
    totalCommuterCash = 0.0;
    for (var c in vehicleData!.commuterCashPayments) {
      totalCommuterCash += c.amount!;
    }
    totalRankFeeCash = 0.0;
    for (var c in vehicleData!.rankFeeCashPayments) {
      totalRankFeeCash += c.amount!;
    }
    int totalPassengers = 0;

    for (var c in vehicleData!.passengerCounts) {
      totalPassengers += c.passengersIn!;
    }
  }

  @override
  Widget build(BuildContext context) {
    _setTotals();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle.vehicleReg}'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Operational Details', style: myTextStyleBold(),),
                vehicleData == null
                    ? gapW32
                    : Expanded(
                        child: ListView(
                        children: [
                          Item(
                            title: 'Dispatches',
                            count: vehicleData!.dispatchRecords.length,
                            padding: Padding(
                              padding: EdgeInsets.all(16),
                            ),
                            style: myTextStyleBold(fontSize: 24),
                          ),
                          Item(
                            title: 'Trips',
                            count: vehicleData!.trips.length,
                            style: myTextStyleBold(fontSize: 24),
                            padding: Padding(padding: EdgeInsets.all(16)),
                          ),
                          Item(
                            title: 'Total Passengers',
                            count: totalPassengers,
                            padding: Padding(
                              padding: EdgeInsets.all(16),
                            ),
                            style: myTextStyleBold(fontSize: 24),
                          ),
                          Item(
                            title: 'Rank Fee Cash',
                            amount: totalRankFeeCash,
                            padding: Padding(
                              padding: EdgeInsets.all(16),
                            ),
                            style: myTextStyleBold(fontSize: 24),
                          ),
                          Item(
                            title: 'Commuter Fee Cash',
                            amount: totalCommuterCash,
                            padding: Padding(
                              padding: EdgeInsets.all(16),
                            ),
                            style: myTextStyleBold(fontSize: 24),
                          ),
                        ],
                      ))
              ],
            ),
            busy
                ? Positioned(child: Center(child: CircularProgressIndicator()))
                : gapW32,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          elevation: 16,
          child: Icon(Icons.refresh),
          onPressed: () {
            _getVehicleData();
          }),
    );
  }
}
