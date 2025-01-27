import 'package:association_official_app/official/official_dashboard.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:kasie_transie_library/auth/phone_auth_signin2.dart';
import 'package:kasie_transie_library/bloc/app_auth.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/data/constants.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/auth/email_auth_signin.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_library/utils/prefs.dart';

import '../official/starter.dart';
import 'intro_page_one.dart';

class KasieIntro extends StatefulWidget {
  const KasieIntro({
    super.key,
    // required this.listApiDog,
  });

  @override
  KasieIntroState createState() => KasieIntroState();
}

class KasieIntroState extends State<KasieIntro>
    with SingleTickerProviderStateMixin {
  final mm = '🍎🍎 KasieIntro 🍎🍎🍎🍎';
  late AnimationController _controller;
  bool authed = false;
  int currentIndexPage = 0;
  final PageController _pageController = PageController();
  fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;
  Prefs prefs = GetIt.instance<Prefs>();
  final DataApiDog dataApiDog = GetIt.instance<DataApiDog>();
  AppAuth appAuth = GetIt.instance<AppAuth>();

  // mrm.User? user;
  String? signInFailed;
  User? user;
  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getAuthenticationStatus();
  }

  void _getAuthenticationStatus() async {
    pp('\n\n$mm _getAuthenticationStatus ....... '
        'check both Firebase user and Kasie user');
    user = prefs.getUser();
    var firebaseUser = appAuth.getUser();

    if (user != null && firebaseUser != null) {
      pp('$mm _getAuthenticationStatus .......  '
          '🥬🥬🥬auth is DEFINITELY authenticated and OK, will navigate to dashboard ...');
      authed = true;
      _navigateToOfficialDashboard();
    } else {
      pp('$mm _getAuthenticationStatus ....... NOT AUTHENTICATED! '
          '🌼🌼🌼 ... will clean house!!');
      authed = false;
      firebaseAuth.signOut();
      pp('$mm _getAuthenticationStatus .......  '
          '🔴🔴🔴🔴'
          'the device should be ready for sign in or registration');
    }
    pp('$mm ......... _getAuthenticationStatus ....... setting state, authed = $authed ');
    setState(() {});
  }

  _clearUser() async {
    await firebaseAuth.signOut();
    prefs.removeUser();
  }

  onSignInWithEmail() async {
    pp('$mm ...  onSignInWithEmail');
    _clearUser();
    if (mounted) {
      NavigationUtils.navigateTo(
          context: context,
          widget: EmailAuthSignin(onGoodSignIn: () {
            onSuccessfulSignIn();
          }, onSignInError: () {
            onFailedSignIn();
          }));
    }
  }

  onSignInWithPhone() async {
    pp('$mm ... onSignInWithPhone ....');
    _clearUser();
    NavigationUtils.navigateTo(
      context: context,
      widget: PhoneAuthSignin(
        onGoodSignIn: () {
          pp('$mm ................................'
              '... onGoodSignIn .... ');
          onSuccessfulSignIn();
        },
        onSignInError: () {
          pp('$mm ................................'
              '... onSignInError ${E.redDot} .... ');
          onFailedSignIn();
        },
      ),
    );
  }

  onRegister() {
    pp('$mm ... onRegister ....');
  }

  void onFailedSignIn() {
    pp('$mm ... onFailedSignIn ....');
  }

  Future<void> onSuccessfulSignIn() async {

    // Navigator.of(context).pop();
    user = prefs.getUser();
    if (user != null) {
      pp('$mm ................................'
          '... onSuccessfulSignIn and user not null.... ');
      myPrettyJsonPrint(user!.toJson());
      if (user!.userType == Constants.ASSOCIATION_OFFICIAL) {
        _navigateToOfficialDashboard();
      }
    }
  }

  void _onPageChanged(int value) {
    pp('$mm onPageChanged ... page: $value');
    setState(() {
      currentIndexPage = value;
    });
  }

  _navigateToOfficialDashboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      if (user!.userType! == Constants.ASSOCIATION_OFFICIAL) {
        pp('$mm navigate to OfficialDashboard ...');
        var ass = prefs.getAssociation();
        NavigationUtils.navigateTo(
          context: context,
          widget: Starter(
            association: ass!,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;
    var color = getTextColorForBackground(Theme.of(context).primaryColor);

    if (isDarkMode) {
      color = Theme.of(context).primaryColor;
    }
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Association Official App',
          style: myTextStyleLargeWithColor(context, color),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: const [
              IntroPage(
                title: 'KasieTransie',
                assetPath: 'assets/intro/pic2.jpg',
                text: lorem,
              ),
              IntroPage(
                  title: 'Organizations',
                  assetPath: 'assets/intro/pic5.jpg',
                  text: lorem),
              IntroPage(
                  title: 'People',
                  assetPath: 'assets/intro/pic1.jpg',
                  text: lorem),
              IntroPage(
                title: 'Field Monitors',
                assetPath: 'assets/intro/pic5.jpg',
                text: lorem,
              ),
              IntroPage(
                title: 'Thank You',
                assetPath: 'assets/intro/pic3.webp',
                text: lorem,
              ),
            ],
          ),
          Positioned(
            bottom: 100,
            left: 48,
            right: 48,
            child: SizedBox(
              width: 200,
              height: 48,
              child: Card(
                color: Colors.black12,
                shape: getRoundedBorder(radius: 8),
                child: DotsIndicator(
                  dotsCount: 5,
                  position: currentIndexPage,
                  decorator: const DotsDecorator(
                    colors: [
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                    ], // Inactive dot colors
                    activeColors: [
                      Colors.pink,
                      Colors.blue,
                      Colors.teal,
                      Colors.indigo,
                      Colors.deepOrange,
                    ], // Àctive dot colors
                  ),
                ),
              ),
            ),
          ),
          Positioned(
              bottom: 8,
              left: 64,
              right: 64,
              child: ElevatedButton(
                style: ButtonStyle(
                  elevation: WidgetStatePropertyAll(8),
                  backgroundColor: WidgetStatePropertyAll(Colors.pink),
                ),
                  onPressed: () {
                    onSignInWithEmail();
                  },
                  child: Text('Sign In', style: myTextStyle(color: Colors.white))))
        ],
      ),
    ));
  }
}

class Header extends StatelessWidget {
  const Header(
      {super.key,
      required this.onSignInWithEmail,
      required this.onSignInWithPhone,
      required this.onRegister});

  final Function onSignInWithEmail, onSignInWithPhone, onRegister;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: DropdownButton<int>(
        hint: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Please select the kind of sign in',
            style: myTextStyleMedium(context),
          ),
        ),
        items: const [
          DropdownMenuItem(
              value: 0,
              child: Row(
                children: [
                  Icon(Icons.phone),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Sign in with your phone'),
                  ),
                ],
              )),
          DropdownMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(Icons.email),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Sign in with your email address'),
                  ),
                ],
              )),
          DropdownMenuItem(
              value: 2,
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Register Your Association'),
                  ),
                ],
              )),
        ],
        onChanged: (index) {
          switch (index) {
            case 0:
              onSignInWithPhone();
              break;
            case 1:
              onSignInWithEmail();
              break;
            case 2:
              onRegister();
              break;
          }
        },
      ),
    );
  }
}
