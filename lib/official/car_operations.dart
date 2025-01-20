import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/commuter_cash_check_in.dart';
import 'package:kasie_transie_library/data/commuter_cash_payment.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/data/rank_fee_cash_check_in.dart';
import 'package:kasie_transie_library/data/rank_fee_cash_payment.dart';
import 'package:kasie_transie_library/maps/vehicle_monitor_map.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:badges/badges.dart' as bd;
import 'package:fluttertoast/fluttertoast.dart';
class CarOperations extends StatefulWidget {
  const CarOperations({super.key, required this.car});

  final lib.Vehicle car;

  @override
  CarOperationsState createState() => CarOperationsState();
}

class CarOperationsState extends State<CarOperations>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<lib.DispatchRecord> dispatches = [];
  List<lib.Trip> trips = [];
  List<lib.AmbassadorPassengerCount> passengerCounts = [];
  List<lib.VehicleTelemetry> vehicleTelemetry = [];
  List<lib.VehicleArrival> vehicleArrivals = [];

  List<CommuterCashPayment> commuterCashPayments = [];
  List<RankFeeCashPayment> rankFeeCashPayments = [];
  FCMService fcmService = GetIt.instance<FCMService>();
  Prefs prefs = GetIt.instance<Prefs>();

  late StreamSubscription<lib.DispatchRecord> dispatchSub;
  late StreamSubscription<lib.AmbassadorPassengerCount> passengerCountSub;
  late StreamSubscription<lib.CommuterRequest> commuterRequestSub;
  late StreamSubscription<CommuterCashPayment> commuterCashPaymentSub;
  late StreamSubscription<CommuterCashCheckIn> commuterCashCheckInSub;
  late StreamSubscription<RankFeeCashPayment> rankFeeCashPaymentSub;
  late StreamSubscription<RankFeeCashCheckIn> rankFeeCashCheckInSub;
  late StreamSubscription<lib.VehicleTelemetry> telemetrySub;
  late StreamSubscription<lib.Trip> tripSub;
  late StreamSubscription<lib.VehicleArrival> vehicleArrivalSub;
  late StreamSubscription<lib.LocationResponse> locationResponselSub;


  int filterHours = 24;
  late Timer timer;
  static const mm = "🍉🍉🍉🍉 CarOperations 🍉";
  bool busy = false;
  lib.VehicleData? vehicleData;
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  DataApiDog dataApiDog = GetIt.instance<DataApiDog>();

  String? startDate, endDate;
  DateTime? startDateTime, endDateTime;
  TimeOfDay? startTimeOfDay, endTimeOfDay;
  bool datesAreCollected = false;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    startDate =
        DateTime.now().subtract(Duration(hours: filterHours)).toIso8601String();
    endDate = DateTime.now().toIso8601String();
    _setUpFCMMessaging();
    pp('$mm Car operations for this car: ');
    myPrettyJsonPrint(widget.car.toJson());
    _startTimer();
    _getData();
  }

  _pickDates(bool isStartDate) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      if (isStartDate) {
        datesAreCollected = false;
        startDateTime = await showDatePicker(
          context: context,
          helpText: isStartDate ? 'Start Date' : 'End Date',
          confirmText: 'Confirm Start Date ',
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(Duration(days: 365)),
          barrierDismissible: false,
        );
        var dt = DateTime(
            startDateTime!.year, startDateTime!.month, startDateTime!.day);
        startDateTime = dt;
        startDate = startDateTime!.toIso8601String();
        pp('$mm check start time; startDateTime: $startDate');
        _pickDates(false);
      } else {
        endDateTime = await showDatePicker(
          context: context,
          helpText: isStartDate ? 'Start Date' : 'End Date',
          confirmText: 'Confirm End Date',
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(Duration(days: 365)),
          barrierDismissible: false,
        );
        var dt = DateTime(endDateTime!.year, endDateTime!.month,
            endDateTime!.day, 23, 59, 59);
        endDateTime = dt;
        endDate = endDateTime!.toIso8601String();
        _getData();
        pp('$mm check end time; endDateTime: $endDate');
      }
      setState(() {});
    }
  }

  Future<void> _setUpFCMMessaging() async {
    await fcmService.initialize();
    var ass = prefs.getAssociation();
    if (ass != null) {
      fcmService.subscribeForOfficial(ass, 'AssociationOfficial');
    }

    dispatchSub = fcmService.dispatchStream.listen((dr) {
      pp('$mm stream delivered dispatchRecord: ');
      myPrettyJsonPrint(dr.toJson());
      _getData();
    });
    passengerCountSub =
        fcmService.passengerCountStream.listen((passengerCount) {
      pp('$mm stream delivered passengerCount: ');
      myPrettyJsonPrint(passengerCount.toJson());
      _getData();
    });
    commuterCashPaymentSub =
        fcmService.commuterCashPaymentStream.listen((payment) {
      pp('\n$mm stream delivered commuterCashPayment: ');
      myPrettyJsonPrint(payment.toJson());
      _getData();
    });

    rankFeeCashPaymentSub =
        fcmService.rankFeeCashPaymentStream.listen((payment) {
      pp('\n$mm stream delivered .rankFeeCashPayment: ');
      myPrettyJsonPrint(payment.toJson());
      _getData();
    });

    tripSub = fcmService.tripStream.listen((trip) {
      pp('\n$mm stream delivered trip: ');
      myPrettyJsonPrint(trip.toJson());
      _getData();
    });
    //
    telemetrySub = fcmService.vehicleTelemetryStream.listen((telemetry) {
      pp('\n$mm stream delivered telemetry: ');
      myPrettyJsonPrint(telemetry.toJson());
    });

    vehicleArrivalSub = fcmService.vehicleArrivalStream.listen((arrival) {
      pp('\n$mm stream delivered vehicleArrival: ');
      myPrettyJsonPrint(arrival.toJson());
      _getData();
    });
    locationResponselSub = fcmService.locationResponseStream.listen((response) {
      pp('\n$mm stream delivered locationResponse: ');
      myPrettyJsonPrint(response.toJson());
      _navigateToMap(response);
    });
  }

  void _navigateToMap(lib.LocationResponse response) async {
    pp('\n$mm stream delivered locationResponse: ');
    NavigationUtils.navigateTo(context: context, widget: VehicleMonitorMap(vehicle: widget.car));

  }

  _startTimer() {
    timer = Timer.periodic(const Duration(minutes: 3), (timer) {
      pp('$mm Timer tick ${timer.tick} - refresh data ...');
      _getData();
    });
  }

  _getData() async {
    pp('$mm ................................... refresh data ...');
    setState(() {
      busy = true;
    });
    try {
      vehicleData = await listApiDog.getVehicleData(
          vehicleId: widget.car.vehicleId!,
          startDate: DateTime.parse(startDate!).toUtc().toIso8601String(),
          endDate: DateTime.parse(endDate!).toUtc().toIso8601String());
      createLists();
    } catch (e, s) {
      pp('$e $s');
      if (mounted) {
        showErrorToast(message: '$e', context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  Future<void> createLists() async {
    setState(() {
      dispatches.clear();
    });
    for (var dr in vehicleData!.dispatchRecords) {
      dispatches.add(dr);
    }
    setState(() {
      trips.clear();
    });
    for (var dr in vehicleData!.trips) {
      trips.add(dr);
    }

    setState(() {
      passengerCounts.clear();
    });
    for (var dr in vehicleData!.passengerCounts) {
      passengerCounts.add(dr);
    }

    setState(() {
      vehicleTelemetry.clear();
    });

    for (var dr in vehicleData!.vehicleTelemetry) {
      vehicleTelemetry.add(dr);
    }

    setState(() {
      commuterCashPayments.clear();
    });

    for (var dr in vehicleData!.commuterCashPayments) {
      commuterCashPayments.add(dr);
    }

    _getTotalPassengers();
    _getAggregateCommuterCash();
    setState(() {});
  }

  double totalCommuterCash = 0.00;

  _getAggregateCommuterCash() {
    totalCommuterCash = 0.0;
    for (var cc in commuterCashPayments) {
      totalCommuterCash += cc.amount!;
    }
    pp('$mm _getAggregateCommuterCash: totalCommuterCash: $totalCommuterCash');
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  int totalPassengers = 0;

  int _getTotalPassengers() {
    totalPassengers = 0;
    for (var m in passengerCounts) {
      if (m.passengersIn != null) {
        totalPassengers += m.passengersIn!;
      }
    }
    pp('$mm _getTotalPassengers: totalPassengers: $totalPassengers');

    setState(() {});
    return totalPassengers;
  }

  _requestLocation() async {
    pp('$mm request car location ...');
    var user = prefs.getUser();
    try {
      var lr = lib.LocationRequest(
          vehicleId: widget.car.vehicleId!,
          vehicleReg: widget.car.vehicleReg,
          userId: user!.userId,
          userName: '${user.firstName} ${user.lastName}',
          associationId: user.associationId);
      var rest = await dataApiDog.addLocationRequest(lr);
      pp('$mm request car location ... ${rest.toJson()}');
      if (mounted) {
        showOKToast(
            duration: const Duration(seconds: 2),
            padding: 24,
            toastGravity: ToastGravity.TOP,
            message: 'Location requested for ${widget.car.vehicleReg}', context: context);
      }

    } catch (e) {
      pp(e);
      if (mounted) {
        showErrorToast(message: '$e', context: context);
      }
    }
  }

  _createFile() async {}

  @override
  Widget build(BuildContext context) {
    DateFormat df = DateFormat.MMMMEEEEd();
    NumberFormat nf = NumberFormat('###,###,##0.00');
    String? start, end;
    if (startDate != null) {
      start = df.format(DateTime.parse(startDate!));
      end = df.format(DateTime.parse(endDate!));
    }
    _getAggregateCommuterCash();
    return Scaffold(
        appBar: AppBar(
          title: const Text('Car Operations'),
        ),
        body: SafeArea(
            child: Stack(
          children: [
            Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SingleChildScrollView(
                        child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('${widget.car.vehicleReg}',
                                style: myTextStyle(
                                    weight: FontWeight.w900, fontSize: 36)),
                            IconButton(
                                onPressed: () {
                                  _requestLocation();
                                },
                                icon: const FaIcon(
                                    FontAwesomeIcons.mapLocationDot,
                                    size: 16,
                                    color: Colors.blue)),
                            IconButton(
                                onPressed: () {
                                  _pickDates(true);
                                },
                                icon: const FaIcon(
                                  FontAwesomeIcons.arrowsRotate,
                                  size: 16,
                                )),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(
                              height: 48,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text('Starting',
                                            style: myTextStyle(
                                                color: Colors.grey,
                                                weight: FontWeight.w900)),
                                      ),
                                      Text(start ?? '',
                                          style: myTextStyle(
                                              color: Colors.grey,
                                              weight: FontWeight.normal)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          'Ending',
                                          style: myTextStyle(
                                              color: Colors.grey,
                                              weight: FontWeight.w900),
                                        ),
                                      ),
                                      Text(end ?? '',
                                          style: myTextStyle(
                                              color: Colors.grey,
                                              weight: FontWeight.normal)),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        ActivityPanel(
                          title: 'Dispatches',
                          textStyle: myTextStyle(
                              color: Colors.green,
                              fontSize: 36,
                              weight: FontWeight.w900),
                          count: dispatches.length,
                        ),
                        ActivityPanel(
                          title: 'Trips',
                          textStyle: myTextStyle(
                              color: Colors.blue,
                              fontSize: 36,
                              weight: FontWeight.w900),
                          count: trips.length,
                        ),
                        ActivityPanel(
                          title: 'Total Passengers',
                          textStyle: myTextStyle(
                              color: Colors.pink,
                              fontSize: 36,
                              weight: FontWeight.w900),
                          count: totalPassengers,
                        ),
                        ActivityPanel(
                          title: 'Telemetry',
                          textStyle: myTextStyle(
                              color: Colors.grey,
                              fontSize: 24,
                              weight: FontWeight.normal),
                          count: vehicleTelemetry.length,
                        ),
                        ActivityPanel(
                          title: 'Passenger Counts',
                          textStyle: myTextStyle(
                              color: Colors.grey,
                              fontSize: 24,
                              weight: FontWeight.normal),
                          count: passengerCounts.length,
                        ),
                        gapH8,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Total Commuter Cash',
                              style: myTextStyle(
                                  color: Colors.grey,
                                  weight: FontWeight.w900,
                                  fontSize: 16),
                            ),
                            Text(
                              nf.format(totalCommuterCash),
                              style: myTextStyle(
                                  weight: FontWeight.w900, fontSize: 28),
                            ),
                          ],
                        ),
                      ],
                    )))),
            busy
                ? Positioned(
                    bottom: 2,
                    right: 2,
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                        )),
                  )
                : gapW32,
          ],
        )));
  }
}

class ActivityPanel extends StatelessWidget {
  const ActivityPanel(
      {super.key,
      required this.title,
      this.amount,
      this.count,
      this.elevation,
      this.textStyle});

  final String title;
  final double? amount;
  final int? count;
  final double? elevation;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    var num = '';
    NumberFormat nf = NumberFormat('###,##0.00');
    NumberFormat nf2 = NumberFormat('###,###,###');

    if (amount != null) {
      num = nf.format(amount);
    }

    if (count != null) {
      num = nf2.format(count);
    }
    return Card(
        elevation: elevation ?? 2,
        child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(title,
                      style: myTextStyle(
                          weight: FontWeight.normal, color: Colors.grey)),
                ),
                gapW32,
                bd.Badge(
                  badgeContent: Text(num,
                      style: myTextStyle(
                          weight: FontWeight.normal,
                          color: Colors.white,
                          fontSize: 16)),
                  badgeStyle: bd.BadgeStyle(
                      badgeColor: textStyle!.color!,
                      elevation: 8,
                      padding: EdgeInsets.all(16)),
                )
              ],
            )));
  }
}
