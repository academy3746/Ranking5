import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_pro/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rank5/features/msg_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebviewController extends StatefulWidget {
  const WebviewController({Key? key}) : super(key: key);

  @override
  State<WebviewController> createState() => _WebviewControllerState();
}

class _WebviewControllerState extends State<WebviewController> {
  // URL 초기화
  final String url = "http://ranking5.sogeum.kr/";
  // 인덱스 페이지 초기화
  bool isInMainPage = true;
  // 웹뷰 컨트롤러 초기화
  final Completer<WebViewController> _controller =
  Completer<WebViewController>();

  WebViewController? _viewController;

  // GPS 초기화
  Position? _position;

  // 푸시 추가 부분
  final MsgController _msgController = Get.put(MsgController());

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) WebView.platform = AndroidWebView();
    _requestPermission();
    _requestStoragePermission();
  }

  // 위치 권한 요청
  Future<void> _requestPermission() async {
    final status = await Geolocator.checkPermission();

    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (status == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 권한 요청이 거부되었습니다.")));
      return;
    }

    await _updatePosition();
  }

  // 위치 정보 업데이트
  Future<void> _updatePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        if (kDebugMode) {
          print(_position);
        }
        _position = position;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 정보를 받아오는 데 실패했습니다.")));
    }
  }

  // 저장매체 접근 권한 요청
  void _requestStoragePermission() async {
    PermissionStatus status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      PermissionStatus result =
      await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print('저장소 접근 권한이 승인되었습니다.');
        }
      } else {
        if (kDebugMode) {
          print('저장소 접근 권한이 거부되었습니다.');
        }
      }
    }
  }

  // 쿠키 획득
  Future<String> _getCookies(WebViewController controller) async {
    final String cookies =
    await controller.runJavascriptReturningResult('document.cookie;');
    return cookies;
  }

  // 쿠키 설정
  Future<void> _setCookies(WebViewController controller, String cookies) async {
    await controller
        .runJavascriptReturningResult('document.cookie="$cookies";');
  }

  // 쿠키 저장
  Future<void> _saveCookies(String cookies) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  // 쿠키 로드
  Future<String?> _loadCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies');
  }

  // 네이티브 ~ 웹 서버 통신
  JavascriptChannel _flutterWebviewProJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'flutter_webview_pro',
      onMessageReceived: (JavascriptMessage message) async {
        Map<String, dynamic> jsonData = jsonDecode(message.message);
        if (jsonData['handler'] == 'webviewJavaScriptHandler') {
          if (jsonData['action'] == 'setUserId') {
            String userId = jsonData['data']['userId'];
            GetStorage().write('userId', userId);

            if (kDebugMode) {
              print('@addJavaScriptHandler userId $userId');
            }

            String? token = await _getPushToken();
            _viewController?.runJavascript('tokenUpdate("$token")');
          }
        }
        setState(() {});
      },
    );
  }

  Future<String?> _getPushToken() async {
    return await _msgController.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        scrollDirection: Axis.vertical,
        child: SizedBox(
          height: MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom,
          child: Stack(
            children: [
              WillPopScope(
                onWillPop: () async {
                  if (_viewController == null) {
                    return false;
                  }

                  final currentUrl = await _viewController?.currentUrl();

                  if (currentUrl == url) {
                    if (!mounted) return false;
                    return showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("앱을 종료하시겠습니까?"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                                if (kDebugMode) {
                                  print("앱이 포그라운드에서 종료되었습니다.");
                                }
                              },
                              child: const Text("확인"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                                if (kDebugMode) {
                                  print("앱이 종료되지 않았습니다.");
                                }
                              },
                              child: const Text("취소"),
                            ),
                          ],
                        );
                      },
                    ).then((value) => value ?? false);
                  } else if (await _viewController!.canGoBack() &&
                      _viewController != null) {
                    _viewController!.goBack();
                    if (kDebugMode) {
                      print("이전 페이지로 이동하였습니다.");
                    }
                    isInMainPage = false;
                    return false;
                  }
                  return false;
                },
                child: SafeArea(
                  child: WebView(
                    initialUrl: url,
                    javascriptMode: JavascriptMode.unrestricted,
                    // ignore: prefer_collection_literals
                    javascriptChannels: <JavascriptChannel>[
                      _flutterWebviewProJavascriptChannel(context),
                    ].toSet(),
                    userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
                    onWebResourceError: (error) {
                      if (kDebugMode) {
                        print("Error Code: ${error.errorCode}");
                        print("Error Description: ${error.description}");
                      }
                    },
                    onWebViewCreated: (WebViewController webviewController) async {
                      _controller.complete(webviewController);
                      _viewController = webviewController;

                      webviewController.currentUrl().then((url) {
                        if (url == "http://ranking5.sogeum.kr/") {
                          setState(() {
                            isInMainPage = true;
                          });
                        } else {
                          setState(() {
                            isInMainPage = false;
                          });
                        }
                      });
                    },
                    onPageStarted: (String url) async {
                      if (kDebugMode) {
                        print("Current Page: $url");
                      }
                    },
                    onPageFinished: (String url) async {
                      if (url.contains("http://ranking5.sogeum.kr/") && _viewController != null) {
                        await _viewController!.runJavascript("""
                          (function() {
                            function scrollToFocusedInput(event) {
                              const focusedElement = document.activeElement;
                              if (focusedElement.tagName.toLowerCase() === 'input' || focusedElement.tagName.toLowerCase() === 'textarea') {
                                setTimeout(() => {
                                  focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                }, 500);
                              }
                            }
                  
                            document.addEventListener('focus', scrollToFocusedInput, true);
                          })();
                        """);
                      }

                      if (url.contains("http://ranking5.sogeum.kr/bbs/login.php") && _viewController != null) {
                        // 추후 카카오 or 구글 맵스 API 추가 부분

                        final cookies = await _getCookies(_viewController!);
                        await _saveCookies(cookies);
                      } else {
                        final cookies = await _loadCookies();

                        if (cookies != null) {
                          await _setCookies(_viewController!, cookies);
                        }
                      }
                    },
                    geolocationEnabled: true,
                    zoomEnabled: false,
                    // ignore: prefer_collection_literals
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                      Factory<EagerGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                      ),
                    ].toSet(),
                  ),
                ),
              ),
              if (Platform.isIOS)
                Positioned(
                  right: 20,
                  bottom: 130,
                  child: FloatingActionButton(
                    child: const Icon(
                      Icons.arrow_back,
                    ),
                    onPressed: () async {
                      if (_viewController != null &&
                          (await _viewController!.canGoBack())) {
                        _viewController!.goBack();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
