import 'package:association_official_app/official/official_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';

import 'association_car_operations.dart';

class Starter extends StatefulWidget {
  const Starter({super.key, required this.association});

  final Association association;
  @override
  StarterState createState() => StarterState();
}

class StarterState extends State<Starter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: gapW32,
        title:  Text('Association App', style: myTextStyle(weight: FontWeight.w900, fontSize: 18)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Card(
                      elevation: 84,
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('${widget.association.associationName}',
                              style: myTextStyle(
                                  weight: FontWeight.w800, fontSize: 36, color: Colors.grey.shade400))),
                    )))
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:  Colors.amber.shade50,
        items: [
          BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.gauge), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.screenpal, color: Colors.pink,), label: 'Vehicle Operations'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              NavigationUtils.navigateTo(
                  context: context,
                  widget: OfficialDashboard(association: widget.association));
              break;
            case 1:
              NavigationUtils.navigateTo(
                  context: context,
                  widget: AssociationCarOperations(
                      association: widget.association));
              break;
          }
        },
      ),
    );
  }
}
