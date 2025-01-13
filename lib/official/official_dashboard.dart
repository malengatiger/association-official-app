import 'dart:async';

import 'package:badges/badges.dart' as bd;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/commuter_cash_check_in.dart';
import 'package:kasie_transie_library/data/commuter_cash_payment.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/data/rank_fee_cash_check_in.dart';
import 'package:kasie_transie_library/data/rank_fee_cash_payment.dart';
import 'package:kasie_transie_library/maps/map_viewer.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/ambassador/association_vehicle_photo_handler.dart';
import 'package:kasie_transie_library/widgets/ambassador/cars_for_ambassador.dart';
import 'package:kasie_transie_library/widgets/ambassador/routes_for_ambassador.dart';
import 'package:kasie_transie_library/widgets/dash_widgets/generic.dart';
import 'package:kasie_transie_library/widgets/vehicle_passenger_count.dart';
import 'package:uuid/uuid.dart';

class OfficialDashboard extends StatefulWidget {
  const OfficialDashboard({super.key, required this.association});

  final lib.Association association;

  @override
  OfficialDashboardState createState() => OfficialDashboardState();
}

class OfficialDashboardState extends State<OfficialDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  lib.User? user;
  Prefs prefs = GetIt.instance<Prefs>();
  lib.Route? route;
  lib.Vehicle? car;
  lib.Trip? trip;
  DeviceLocationBloc deviceLocationBloc = GetIt.instance<DeviceLocationBloc>();
  FCMService fcmService = GetIt.instance<FCMService>();
  DataApiDog dataApi = GetIt.instance<DataApiDog>();

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

  List<lib.DispatchRecord> dispatches = [];
  List<lib.AmbassadorPassengerCount> passengerCounts = [];
  List<lib.CommuterRequest> commuterRequests = [];
  List<CommuterCashPayment> commuterCashPayments = [];
  List<CommuterCashCheckIn> commuterCashCheckIns = [];
  List<RankFeeCashPayment> rankFeeCashPayments = [];
  List<RankFeeCashCheckIn> rankFeeCashCheckIns = [];
  List<lib.VehicleTelemetry> vehicleTelemetry = [];
  List<lib.Trip> trips = [];
  List<lib.VehicleArrival> vehicleArrivals = [];

//
  List<lib.User> users = [];
  List<lib.Vehicle> vehicles = [];
  List<lib.Route> routes = [];

  int totalPassengersIn = 0;
  int totalPassengersRequests = 0;
  int totalDispatchedPassengers = 0;

  double totalCommuterCash = 0.00;
  double totalRankFeeCash = 0.00;
  double totalCashCheckIn = 0.00;
  double totalRankFeeCheckIn = 0.00;
  static const mm = '🥦️🥦️🥦️🥦️OfficialDashboard 🥦️🥦️';
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  late Timer timer;
  DateTime? startDateTime, endDateTime;
  TimeOfDay? startTimeOfDay, endTimeOfDay;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _setUpFCMMessaging();
    user = prefs.getUser();
    route = prefs.getRoute();
    car = prefs.getCar();
    _signIn();
  }

  Future<void> _setUpFCMMessaging() async {
    await fcmService.initialize();
    var ass = prefs.getAssociation();
    if (ass != null) {
      fcmService.subscribeForOfficial(ass, 'AssociationOfficial');
    }

    commuterRequestSub = fcmService.commuterRequestStream.listen((req) {
      commuterRequests.add(req);
      _filterCommuterRequests(commuterRequests);
      if (mounted) {
        setState(() {});
      }
    });
    dispatchSub = fcmService.dispatchStream.listen((dr) {
      dispatches.add(dr);
      _filterDispatches(dispatches);
      if (mounted) {
        setState(() {});
      }
    });
    passengerCountSub =
        fcmService.passengerCountStream.listen((passengerCount) {
      passengerCounts.add(passengerCount);
      _filterPassengerCounts(passengerCounts);
      if (mounted) {
        setState(() {});
      }
    });
    commuterCashPaymentSub =
        fcmService.commuterCashPaymentStream.listen((payment) {
      commuterCashPayments.add(payment);
      _filterCommuterCashPayments(commuterCashPayments);
      if (mounted) {
        setState(() {});
      }
    });
    commuterCashCheckInSub =
        fcmService.commuterCashCheckInStream.listen((checkIn) {
      commuterCashCheckIns.add(checkIn);
      _filterCommuterCashCheckIns(commuterCashCheckIns);
      if (mounted) {
        setState(() {});
      }
    });
    rankFeeCashCheckInSub =
        fcmService.rankFeeCashCheckInStream.listen((checkIn) {
      rankFeeCashCheckIns.add(checkIn);
      _filterRankFeeCashCheckIns(rankFeeCashCheckIns);
      if (mounted) {
        setState(() {});
      }
    });
    rankFeeCashPaymentSub =
        fcmService.rankFeeCashPaymentStream.listen((payment) {
      rankFeeCashPayments.add(payment);
      _filterCommuterCashPayments(commuterCashPayments);
      if (mounted) {
        setState(() {});
      }
    });
    tripSub = fcmService.tripStream.listen((trip) {
      trips.add(trip);
      _filterTrips(trips);
      if (mounted) {
        setState(() {});
      }
    });
    //
    telemetrySub = fcmService.vehicleTelemetryStream.listen((trip) {
      vehicleTelemetry.add(trip);
      _filterTelemetry(vehicleTelemetry);
      if (mounted) {
        setState(() {});
      }
    });
    vehicleArrivalSub = fcmService.vehicleArrivalStream.listen((trip) {
      vehicleArrivals.add(trip);
      _filterVehicleArrivals(vehicleArrivals);
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool datesAreCollected = false;

  _getDate(bool isStartDate) async {
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
        _getDate(false);
      } else {
        endDateTime = await showDatePicker(
          context: context,
          helpText: isStartDate ? 'Start Date' : 'End Date',
          confirmText: 'Confirm End Date',
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(Duration(days: 365)),
          barrierDismissible: false,
        );
      }
    }
  }

  _getTime({required bool isStartDate}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      if (isStartDate) {
        startTimeOfDay = await showTimePicker(
            barrierDismissible: false,
            context: context,
            initialTime: TimeOfDay.now());
        _getDate(true);
        return;
      } else {
        endTimeOfDay = await showTimePicker(
            barrierDismissible: false,
            context: context,
            initialTime: TimeOfDay.now());

        setState(() {});
      }
    }
  }

  DateTime mergeDateTimeAndTimeOfDay(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  List<lib.VehicleArrival> _filterVehicleArrivals(
      List<lib.VehicleArrival> counts) {
    pp('$mm _filterVehicleArrivals arrived: ${counts.length}');

    List<lib.VehicleArrival> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterVehicleArrivals difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterVehicleArrivals filtered: ${filtered.length}');
    setState(() {
      vehicleArrivals = filtered;
    });
    return filtered;
  }

  List<lib.VehicleTelemetry> _filterTelemetry(
      List<lib.VehicleTelemetry> counts) {
    pp('$mm _filterTelemetry arrived: ${counts.length}');

    List<lib.VehicleTelemetry> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterTelemetry difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterTelemetry filtered: ${filtered.length}');
    setState(() {
      vehicleTelemetry = filtered;
    });
    return filtered;
  }

  List<lib.Trip> _filterTrips(List<lib.Trip> counts) {
    pp('$mm _filterTrips arrived: ${counts.length}');

    List<lib.Trip> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterTrips difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterTrips filtered: ${filtered.length}');
    setState(() {
      trips = filtered;
    });
    return filtered;
  }

  List<RankFeeCashCheckIn> _filterRankFeeCashCheckIns(
      List<RankFeeCashCheckIn> counts) {
    pp('$mm _filterRankFeeCashCheckIns arrived: ${counts.length}');

    List<RankFeeCashCheckIn> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterRankFeeCashCheckIns difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterRankFeeCashCheckIns filtered: ${filtered.length}');
    setState(() {
      rankFeeCashCheckIns = filtered;
    });
    return filtered;
  }

  List<RankFeeCashPayment> _filterRankFeeCashPayments(
      List<RankFeeCashPayment> counts) {
    pp('$mm _filterRankFeeCashPayments arrived: ${counts.length}');

    List<RankFeeCashPayment> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterRankFeeCashPayments difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterPassengerCounts filtered: ${filtered.length}');
    setState(() {
      rankFeeCashPayments = filtered;
    });
    return filtered;
  }

  List<CommuterCashCheckIn> _filterCommuterCashCheckIns(
      List<CommuterCashCheckIn> counts) {
    pp('$mm _filterCommuterCashCheckIns arrived: ${counts.length}');

    List<CommuterCashCheckIn> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterCommuterCashCheckIns difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterCommuterCashCheckIns filtered: ${filtered.length}');
    setState(() {
      commuterCashCheckIns = filtered;
    });
    return filtered;
  }

  List<CommuterCashPayment> _filterCommuterCashPayments(
      List<CommuterCashPayment> counts) {
    pp('$mm _filterCommuterCashPayments arrived: ${counts.length}');

    List<CommuterCashPayment> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterCommuterCashPayments difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterCommuterCashPayments filtered: ${filtered.length}');
    setState(() {
      commuterCashPayments = filtered;
    });
    return filtered;
  }

  List<lib.AmbassadorPassengerCount> _filterPassengerCounts(
      List<lib.AmbassadorPassengerCount> counts) {
    pp('$mm _filterPassengerCounts arrived: ${counts.length}');

    List<lib.AmbassadorPassengerCount> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in counts) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm _filterPassengerCounts difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterPassengerCounts filtered: ${filtered.length}');
    setState(() {
      passengerCounts = filtered;
    });
    return filtered;
  }

  List<lib.DispatchRecord> _filterDispatches(
      List<lib.DispatchRecord> requests) {
    pp('$mm _filterDispatches arrived: ${requests.length}');

    List<lib.DispatchRecord> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in requests) {
      var date = DateTime.parse(r.created!);
      var difference = now.difference(date);
      pp('$mm filterDispatchRecord difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterDispatches filtered: ${filtered.length}');
    setState(() {
      dispatches = filtered;
    });
    return filtered;
  }

  _initializeTimer() async {
    pp('\n\n$mm initialize Timer for ambassador commuters');
    timer = Timer.periodic(Duration(seconds: 60), (timer) {
      pp('\n\n$mm Timer tick #${timer.tick} - _filterCommuterRequests ...');
      _filterCommuterRequests(commuterRequests);
    });
    pp('\n\n$mm  Ambassador Timer initialized for 🌀 60 seconds per tick🌀');
  }

  void _getCommuterRequests() async {
    var date = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    commuterRequests = await listApiDog.getRouteCommuterRequests(
        routeId: route!.routeId!, startDate: date.toIso8601String());
    if (mounted) {
      setState(() {});
    }
  }

  List<lib.CommuterRequest> _filterCommuterRequests(
      List<lib.CommuterRequest> requests) {
    pp('$mm _filterCommuterRequests arrived: ${requests.length}');

    List<lib.CommuterRequest> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in requests) {
      var date = DateTime.parse(r.dateRequested!);
      var difference = now.difference(date);
      pp('$mm _filterCommuterRequests difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterCommuterRequests filtered: ${filtered.length}');
    setState(() {
      commuterRequests = filtered;
    });
    return filtered;
  }

  int _getPassengers() {
    var cnt = 0;
    for (var cr in commuterRequests) {
      cnt += cr.numberOfPassengers!;
    }
    return cnt;
  }

  @override
  void dispose() {
    _controller.dispose();
    commuterRequestSub.cancel();
    timer.cancel();
    super.dispose();
  }

  _signIn() async {
    if (user != null) {
      var u = await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: user!.email!, password: user!.password!);
      if (u.user != null) {
        pp('$mm user has signed in');
        _initializeTimer();
        _getData();
        if (mounted) {
          showOKToast(
              duration: const Duration(seconds: 2),
              message: 'User signed in successfully!',
              context: context);
        }
      }
    }
  }

  _navigateToRoutes() async {
    route = await NavigationUtils.navigateTo(
        context: context,
        widget: NearestRoutesList(
          associationId: widget.association.associationId!,
          title: 'Ambassador Routes',
        ));

    if (route != null) {
      prefs.saveRoute(route!);
      _getCommuterRequests();
      _navigateToCarSearch(route!);
    }
  }

  _confirmCar() {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
              content: SizedBox(
                  height: 140,
                  child: Column(
                    children: [
                      gapH16,
                      Text('Do you want to work in your previous taxi?  '),
                      gapH32,
                      Text(
                        ' ${car!.vehicleReg}',
                        style:
                            myTextStyle(fontSize: 32, weight: FontWeight.w900),
                      )
                    ],
                  )),
              actions: [
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      car = await NavigationUtils.navigateTo(
                          context: context,
                          widget: CarForAmbassador(
                            associationId: widget.association.associationId!,
                          ));

                      if (car != null) {
                        trip = await _getTrip(route!, car!);
                        prefs.saveCar(car!);
                        _navigateToPassengerCount(route!, car!);
                      }
                    },
                    child: const Text('No')),
                TextButton(
                    onPressed: () async {
                      trip = await _getTrip(route!, car!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        _navigateToPassengerCount(route!, car!);
                      }
                    },
                    child: const Text('Yes')),
              ]);
        });
  }

  _navigateToCarSearch(lib.Route route) async {
    if (car != null) {
      _confirmCar();
      return;
    }
    car = await NavigationUtils.navigateTo(
        context: context,
        widget: CarForAmbassador(
          associationId: widget.association.associationId!,
        ));

    if (car != null) {
      trip = await _getTrip(route, car!);
      prefs.saveCar(car!);
      _navigateToPassengerCount(route, car!);
    }
  }

  _navigateToPassengerCount(lib.Route route, lib.Vehicle vehicle) async {
    trip ??= await _getTrip(route, vehicle);
    if (mounted) {
      NavigationUtils.navigateTo(
          context: context,
          widget: VehiclePassengerCount(
            vehicle: vehicle,
            route: route,
            trip: trip!,
          ));
    }
  }

  Future<lib.Trip?> _getTrip(lib.Route route, lib.Vehicle vehicle) async {
    var loc = await deviceLocationBloc.getLocation();
    var user = prefs.getUser();
    lib.Trip? trip;
    if (user != null) {
      trip = lib.Trip(
          tripId: Uuid().v4().toString(),
          userId: user.userId!,
          userName: '${user.firstName} ${user.lastName}',
          dateStarted: DateTime.now().toUtc().toIso8601String(),
          dateEnded: null,
          routeId: route.routeId!,
          routeName: route.name!,
          vehicleId: car!.vehicleId,
          vehicleReg: car!.vehicleReg,
          associationId: widget.association.associationId!,
          associationName: widget.association.associationName,
          position: lib.Position(
              coordinates: [loc.longitude, loc.latitude], type: 'Point'),
          created: DateTime.now().toUtc().toIso8601String());
      dataApi.addTrip(trip);
      fcmService.subscribeForAmbassador(route, 'Ambassador');
    }
    return trip;
  }

  _navigateToAssociationPhotos() {
    NavigationUtils.navigateTo(
        context: context, widget: AssociationVehiclePhotoHandler());
  }

  String? startDate, endDate;
  bool busy = false;
  lib.AssociationData? associationData;

  void _getData() async {
    pp('\n\n$mm  ........... getting association data bundle .... $startDate  - $endDate');
    setState(() {
      busy = true;
    });
    startDate ??= DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    endDate ??= DateTime.now().toUtc().toIso8601String();

    var user = prefs.getUser();
    associationData = await listApiDog.getAssociationData(
        associationId: user!.associationId!,
        startDate: startDate!,
        endDate: endDate!);
    if (associationData != null) {
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
    }
    setState(() {
      busy = false;
    });
  }

  int _getDispatchedPassengers() {
    var tot = 0;
    for (var value in dispatches) {
      tot += value.passengers!;
    }
    return tot;
  }

  double _getRankFeeCashCheckIn() {
    var tot = 0.00;
    for (var value in rankFeeCashCheckIns) {
      tot += value.amount!;
    }
    return tot;
  }

  double _getCommuterCashCheckIn() {
    var tot = 0.00;
    for (var value in commuterCashCheckIns) {
      tot += value.amount!;
    }
    return tot;
  }

  int _getPassengersRequests() {
    var tot = 0;
    for (var value in commuterRequests) {
      tot += value.numberOfPassengers!;
    }
    return tot;
  }

  double _getCommuterCash() {
    var tot = 0.00;
    for (var value in commuterCashPayments) {
      tot += value.amount!;
    }
    return tot;
  }

  double _getRankFees() {
    var tot = 0.00;
    for (var value in rankFeeCashPayments) {
      tot += value.amount!;
    }
    return tot;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Association Official', style: myTextStyle()),
          leading: gapW32,
          actions: [
            IconButton(
                onPressed: () {
                  _navigateToAssociationPhotos();
                },
                icon: FaIcon(FontAwesomeIcons.camera)),
          ]),
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                user == null
                    ? gapW32
                    : Text('${user!.firstName} ${user!.lastName}',
                        style: myTextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                            weight: FontWeight.w700)),
                gapH32,
                // Padding(
                //   padding: EdgeInsets.all(16),
                //   child: DashElements(isGrid: false),
                // ),
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Expanded(
                            child: GridView(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2),
                          children: [
                            TotalWidget(
                                caption: 'Passengers In',
                                number: totalPassengersIn,
                                color: Colors.green,
                                onTapped: () {
                                  pp('$mm totalPassengersIn tapped');
                                }),
                            TotalWidget(
                                caption: 'Passenger Cash Payments',
                                number: commuterCashPayments.length,
                                onTapped: () {
                                  pp('$mm commuterCashPayments tapped');
                                }),
                            TotalWidget(
                                caption: 'Dispatches',
                                number: dispatches.length,
                                color: Colors.amber.shade800,
                                onTapped: () {
                                  pp('$mm dispatches tapped');
                                }),
                            TotalWidget(
                                caption: 'Dispatched Passengers',
                                number: totalDispatchedPassengers,
                                color: Colors.amber.shade800,
                                onTapped: () {
                                  pp('$mm dispatched passengers tapped');
                                }),
                            TotalWidget(
                                caption: 'Commuter Requests',
                                number: commuterRequests.length,
                                color: Colors.red,
                                onTapped: () {
                                  pp('$mm commuterRequests tapped');
                                }),
                            TotalWidget(
                                caption: 'Passenger Requests',
                                number: totalPassengersRequests,
                                onTapped: () {
                                  pp('$mm totalPassengersRequests tapped');
                                }),
                            TotalWidget(
                                caption: 'Rank Fee Cash Payments',
                                number: totalRankFeeCash.toInt(),
                                onTapped: () {
                                  pp('$mm rankFees tapped');
                                }),
                            TotalWidget(
                                caption: 'Routes',
                                number: routes.length,
                                color: Colors.grey,
                                onTapped: () {
                                  pp('$mm routes tapped');
                                }),
                            TotalWidget(
                                caption: 'Staff',
                                number: users.length,
                                color: Colors.grey,
                                onTapped: () {
                                  pp('$mm users tapped');
                                }),
                            TotalWidget(
                                caption: 'Vehicles',
                                number: vehicles.length,
                                color: Colors.grey,
                                onTapped: () {
                                  pp('$mm vehicles tapped');
                                }),
                          ],
                        )),
                        gapH32,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          route == null
              ? gapW32
              : Positioned(
                  bottom: 2,
                  right: 24,
                  child: SizedBox(
                      height: 140,
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: () {
                              route = prefs.getRoute();
                              setState(() {});
                              _navigateToCarSearch(route!);
                            },
                            child: Text('${route!.name}',
                                style: myTextStyle(
                                    color: Colors.grey,
                                    fontSize: 18,
                                    weight: FontWeight.w900)),
                          ),
                        ],
                      ))),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          onTap: (index) async {
            if (index == 0) {
              pp('$mm bottomNavigationBar: default last 24 hours refresh');
              startDate = DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 24))
                  .toIso8601String();
              endDate = DateTime.now().toUtc().toIso8601String();
              _getData();
            }
            if (index == 1) {
              pp('$mm bottomNavigationBar: past 7 days refresh');
              startDate = DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 7))
                  .toIso8601String();
              endDate = DateTime.now().toUtc().toIso8601String();
              _getData();
            }
            if (index == 2) {
              pp('$mm bottomNavigationBar: build start - end search ');
              await _getDate(true);
              _getData();
            }
          },
          items: [
            BottomNavigationBarItem(
                backgroundColor: Colors.white,
                label: 'Past 24 Hours',
                icon: FaIcon(FontAwesomeIcons.clock, color: Colors.pink,)),
            BottomNavigationBarItem(
                backgroundColor: Colors.teal,
                label: 'Past Week',
                icon: FaIcon(FontAwesomeIcons.arrowsRotate, color: Colors.grey,)),
            BottomNavigationBarItem(
                backgroundColor: Colors.white,
                label: 'Search Period',
                icon: FaIcon(FontAwesomeIcons.magnifyingGlass, color: Colors.blue,)),
          ]),
    );
  }

  void _navigateToRouteMap() {
    pp('$mm ..... _navigateToRouteMap');
    if (route != null) {
      NavigationUtils.navigateTo(
          context: context,
          widget: MapViewer(commuterRequests: commuterRequests, route: route!));
    }
  }
}
