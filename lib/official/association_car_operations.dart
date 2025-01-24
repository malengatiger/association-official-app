import 'dart:async';

import 'package:association_official_app/official/vehicle_map.dart';
import 'package:badges/badges.dart' as bd;
import 'package:firebase_messaging/firebase_messaging.dart' as msg;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/bloc/sem_cache.dart';
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
import 'package:kasie_transie_library/widgets/vehicle_widgets/vehicle_search.dart';

class AssociationCarOperations extends StatefulWidget {
  const AssociationCarOperations({super.key, required this.association});

  final lib.Association association;

  @override
  AssociationCarOperationsState createState() =>
      AssociationCarOperationsState();
}

class AssociationCarOperationsState extends State<AssociationCarOperations>
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
  late StreamSubscription<lib.LocationResponse> locationResponseSub;
  late StreamSubscription<lib.LocationResponseError> locationResponseErrorSub;

  int filterHours = 24;
  late Timer timer;
  static const mm = "🍉🍉🍉🍉 AssociationCarOperations 🍉";
  bool busy = false;
  lib.VehicleData? vehicleData;
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  DataApiDog dataApiDog = GetIt.instance<DataApiDog>();
  SemCache semCache = GetIt.instance<SemCache>();

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

    var dt = DateTime.now();
    endDate = DateTime(dt.year, dt.month, dt.day, 23, 59, 59).toIso8601String();

    _setUpFCMMessaging();
    pp('$mm Car operations for this car: ');
    myPrettyJsonPrint(widget.association.toJson());
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
    locationResponseSub =
        fcmService.locationResponseStream.listen((response) async {
      pp('\n$mm stream delivered locationResponse:  go to VehicleMonitorMap');
      myPrettyJsonPrint(response.toJson());
      var car = await semCache.getVehicle(
          response.associationId!, response.vehicleId!);
      if (car != null) {
        if (mounted) {
          if (locationResponse != null) {
            if (locationResponse!.created! != response.created) {
              _navigateToMap(car, response);
            }
          } else {
            _navigateToMap(car, response);
          }
        }
      }
    });

    locationResponseErrorSub =
        fcmService.locationResponseErrorStream.listen((response) {
      pp('\n$mm stream delivered locationResponseError: ');
      myPrettyJsonPrint(response.toJson());
      // _navigateToMap(response);
    });
  }

  void _navigateToMap(lib.Vehicle car, lib.LocationResponse response) {
     NavigationUtils.navigateTo(
        context: context, widget: VehicleMap(vehicle: car, locationResponse: response,));
    locationResponse = response;
  }

lib.LocationResponse? locationResponse;

  _startTimer() {
    timer = Timer.periodic(const Duration(minutes: 3), (timer) {
      pp('$mm Timer tick ${timer.tick} - refresh data ...');
      _getData();
    });
  }

  lib.AssociationData? associationData;

  List<lib.User> users = [];
  List<lib.Vehicle> vehicles = [];
  List<lib.Route> routes = [];
  List<lib.CommuterRequest> commuterRequests = [];
  List<RankFeeCashCheckIn> rankFeeCashCheckIns = [];

  int totalPassengersIn = 0;
  int totalPassengersRequests = 0;
  int totalDispatchedPassengers = 0;

  double totalCommuterCash = 0.00;
  double totalRankFeeCash = 0.00;
  double totalCashCheckIn = 0.00;
  double totalRankFeeCheckIn = 0.00;

  void _getData() async {
    pp('\n\n$mm  ........... getting association data bundle .... $startDate  - $endDate');
    setState(() {
      busy = true;
    });
    var sd = DateTime.parse(startDate!).toUtc().toIso8601String();
    var ed = DateTime.parse(endDate!).toUtc().toIso8601String();
    pp('\n\n$mm  ........... getting association data bundle; UTC format: .... $sd  - $ed');

    try {
      associationData = await listApiDog.getAssociationData(
          associationId: widget.association.associationId!,
          startDate: sd,
          endDate: ed);

      if (associationData != null) {
        pp('$mm associationData is cool  ...');
        _createLists();
        users = associationData!.users;
        vehicles = associationData!.vehicles;
        routes = associationData!.routes;
        totalPassengersIn = _getPassengers();
        totalRankFeeCash = _getRankFees();
        totalCommuterCash = _getCommuterCash();
        totalPassengersRequests = _getPassengersRequests();
        totalCashCheckIn = _getCommuterCashCheckIn();
        totalRankFeeCheckIn = _getRankFeeCashCheckIn();
        totalDispatchedPassengers = _getDispatchedPassengers();
        dispatches = associationData!.dispatchRecords;
        commuterRequests = associationData!.commuterRequests;
        trips = associationData!.trips;
        commuterCashPayments = associationData!.commuterCashPayments;
      }
      routes.sort((a, b) => a.name!.compareTo(b.name!));

      // pp('$mm  dispatches: ${dispatches.length}');
      // pp('$mm trips: ${trips.length}');
      // pp('$mm commuterRequests: ${commuterRequests.length}');
      // pp('$mm  totalPassengersIn: $totalPassengersIn');
      // pp('$mm totalCommuterCash: $totalCommuterCash');
      // pp('$mm totalPassengersRequests: $totalPassengersRequests');
      // pp('$mm totalDispatchedPassengers: $totalDispatchedPassengers');
      // pp('$mm totalRankFeeCash: $totalRankFeeCash');
      // pp('$mm totalCashCheckIn: $totalCashCheckIn');
      // pp('$mm totalRankFeeCheckIn: $totalRankFeeCheckIn');
      // pp('$mm users: ${users.length} cars: ${vehicles.length} routes: ${routes.length}');

      pp('$mm ........................................................... Are we good?');
    } catch (e, s) {
      pp('$e $s');
    }

    pp('$mm setting state ...');
    setState(() {
      busy = false;
    });
  }

  int _getPassengers() {
    var cnt = 0;
    for (var cr in commuterRequests) {
      cnt += cr.numberOfPassengers!;
    }
    // pp('$mm _getPassengers: $cnt');

    return cnt;
  }

  int _getDispatchedPassengers() {
    var tot = 0;
    for (var value in dispatches) {
      tot += value.passengers!;
    }
    // pp('$mm _getDispatchedPassengers: $tot');

    return tot;
  }

  double _getRankFeeCashCheckIn() {
    var tot = 0.00;
    for (var value in rankFeeCashCheckIns) {
      tot += value.amount!;
    }
    // pp('$mm _getRankFeeCashCheckIn: $tot');

    return tot;
  }

  List<CommuterCashCheckIn> commuterCashCheckIns = [];

  double _getCommuterCashCheckIn() {
    totalCashCheckIn = 0.00;
    for (var value in commuterCashCheckIns) {
      totalCashCheckIn += value.amount!;
    }
    // pp('$mm _getCommuterCashCheckIn: $totalCashCheckIn');

    return totalCashCheckIn;
  }

  int _getPassengersRequests() {
    totalPassengersRequests = 0;
    for (var value in commuterRequests) {
      totalPassengersRequests += value.numberOfPassengers!;
    }
    // pp('$mm _getPassengersRequests: $totalPassengersRequests');

    return totalPassengersRequests;
  }

  double _getCommuterCash() {
    totalCommuterCash = 0.00;
    for (var value in commuterCashPayments) {
      totalCommuterCash += value.amount!;
    }
    pp('$mm _getCommuterCash: $totalCommuterCash');

    return totalCommuterCash;
  }

  double _getRankFees() {
    totalRankFeeCash = 0.00;
    for (var value in rankFeeCashPayments) {
      totalRankFeeCash += value.amount!;
    }
    // pp('$mm _getRankFees: $totalRankFeeCash');

    return totalRankFeeCash;
  }

  Future<void> _createLists() async {
    dispatches.clear();
    for (var dr in associationData!.dispatchRecords) {
      dispatches.add(dr);
    }
    trips.clear();

    for (var dr in associationData!.trips) {
      trips.add(dr);
    }

    passengerCounts.clear();
    for (var dr in associationData!.passengerCounts) {
      passengerCounts.add(dr);
    }

    vehicleTelemetry.clear();

    for (var dr in associationData!.vehicleTelemetry) {
      vehicleTelemetry.add(dr);
    }

    commuterCashPayments.clear();

    for (var dr in associationData!.commuterCashPayments) {
      commuterCashPayments.add(dr);
    }

    _getTotalPassengers();
    _getAggregateCommuterCash();
    setState(() {});
  }

  _getAggregateCommuterCash() {
    totalCommuterCash = 0.0;
    for (var cc in commuterCashPayments) {
      totalCommuterCash += cc.amount!;
    }
    // pp('$mm _getAggregateCommuterCash: totalCommuterCash: $totalCommuterCash');
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
    // pp('$mm _getTotalPassengers: totalPassengers: $totalPassengers');

    setState(() {});
    return totalPassengers;
  }

  lib.Vehicle? selectedVehicle;

  _requestLocation(lib.Vehicle car) async {
    pp('\n\n$mm request car location ... check fcmToken!');
    myPrettyJsonPrint(car.toJson());
    selectedVehicle = car;
    if (car.fcmToken == null) {
      showErrorToast(message: 'Missing fcmToken ', context: context);
      return;
    }
    var user = prefs.getUser();
    var fcmToken = await msg.FirebaseMessaging.instance.getToken();
    try {
      var lr = lib.LocationRequest(
          vehicleId: car.vehicleId!,
          vehicleReg: car.vehicleReg,
          userId: user!.userId,
          fcmToken: fcmToken,
          userName: '${user.firstName} ${user.lastName}',
          associationId: user.associationId,
          vehicleFcmToken: car.fcmToken);
      var rest = await dataApiDog.addLocationRequest(lr);
      pp('$mm car location request sent ... ${rest.toJson()}');
      if (mounted) {
        showOKToast(
            duration: const Duration(seconds: 2),
            padding: 24,
            toastGravity: ToastGravity.TOP,
            message: 'Location requested for ${car.vehicleReg}',
            context: context);
      }
    } catch (e) {
      pp(e);
      if (mounted) {
        showErrorToast(message: '$e', context: context);
      }
    }
  }

  _addLocationRequest() async {
    selectedVehicle = await NavigationUtils.navigateTo(
        context: context,
        widget:
            VehicleSearch(associationId: widget.association.associationId!));
    var user = prefs.getUser();
    if (selectedVehicle != null) {
      _requestLocation(selectedVehicle!);
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
    var pCounts = passengerCounts.length;
    _getAggregateCommuterCash();
    return Scaffold(
        appBar: AppBar(
          title: const Text('Taxi Operations'),
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
                            Text('${widget.association.associationName}',
                                style: myTextStyle(
                                    weight: FontWeight.w900, fontSize: 16)),
                            IconButton(
                                onPressed: () {
                                  _addLocationRequest();
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
                          count: _getTotalPassengers(),
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
                          count: pCounts,
                        ),
                        gapH8,
                        SizedBox(
                          height: 120,
                          width: 600,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Total Commuter Cash',
                                style: myTextStyle(
                                    color: Colors.grey,
                                    weight: FontWeight.w900,
                                    fontSize: 16),
                              ),
                              Card(
                                elevation: 24,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    nf.format(totalCommuterCash),
                                    style: myTextStyle(
                                        weight: FontWeight.w900, fontSize: 40),
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    )))),
            busy
                ? Positioned(
                    bottom: 4,
                    right: 4,
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
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
            padding: EdgeInsets.all(8),
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
