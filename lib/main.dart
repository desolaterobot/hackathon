import 'package:flutter/material.dart';
import 'package:google_gemini/google_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

Color mainColor = const Color.fromARGB(255, 248, 86, 86);
Color darkerMainColor = Color.fromARGB(255, 255, 71, 71);
Color lighterMainColor = const Color.fromARGB(255, 255, 195, 195);
Color secondaryColor = Color.fromARGB(255, 255, 113, 243);
Color lighterSecondaryColor = const Color.fromARGB(255, 255, 177, 235);

const String help = '''
  Welcome to WhereDat, a handy travel companion to display vital country information from a single photo.

  Start by uploading a photo, then tapping on GENERATE!
''';

String geminiReply = "???";

final gemini = GoogleGemini(
  apiKey: "AIzaSyDx5ldNtJIWhSaGXAAgRPtVy66UYcOWN6M",
);

void main() => runApp(const MaterialApp(
      home: CountryApp(),
    ));

class CountryApp extends StatefulWidget {
  const CountryApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return _CountryApp();
  }
}

class _CountryApp extends State<CountryApp> {
  File? selectedImage;
  String navBarTitle = "WhereDat";
  int indexOfNavBar = 0;
  final ScrollController sc = ScrollController();
  bool isloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lighterMainColor,
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(
          navBarTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: showImage(), //automatically shows
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          pickImageFrom(true);
        }),
        backgroundColor: mainColor,
        child: const Icon(Icons.upload_rounded, color: Colors.white),
      ),
    );
  }

  //returns an Image widget if selectedImage is not null, else, it returns text
  Widget showImage() {
    File? selected = selectedImage;
    if (selected != null && selected.existsSync()) {
      File selectedNotNull = selected;
      imageNotNull = selectedNotNull;
      //fromTextAndImage(query: "Where is this place.", image: _selected);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: SingleChildScrollView(
            controller: sc,
            child: Column(
              children: [
                Image.file(
                  selected, // Replace with the path to your image file
                  fit: BoxFit.cover, // Adjust the BoxFit property as needed
                ),
                const SizedBox(
                  height: 10,
                ),
                !isloading
                    ? ElevatedButton(
                        onPressed: () => getLocation(image: selectedNotNull),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor),
                        child: const Padding(
                          padding: EdgeInsets.all(15.0),
                          child: Text(
                            "GENERATE",
                            style: TextStyle(fontSize: 30, color: Colors.white),
                          ),
                        ))
                    : CircularProgressIndicator(
                        color: mainColor,
                      ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
            child: Text(
            help,
            style: TextStyle(color: darkerMainColor, fontSize: 21),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  //opens file explorer or camera to select image.
  Future pickImageFrom(bool fromGallery) async {
    String? returnedImage = Platform.isWindows
        ? (await FilePicker.platform.pickFiles(
            type: FileType.image,
          ))?.files.single.path
        : (await ImagePicker().pickImage(
            source: fromGallery ? ImageSource.gallery : ImageSource.camera))?.path;
    if (returnedImage == null) return;
    setState(() {
      selectedImage = File(returnedImage);
    });
  }

  //from the image given, produce location name as a string. from this,
  void getLocation({required File image}) async {
    setState(() {
      isloading = true;
    });
    showSnackbar(context, "Generating...");
    String query = oneShotPrompt;
    gemini.generateFromTextAndImages(query: query, image: image).then((value) {
      if (value.text == "NO") {
        showErrorSnackbar(
            context,
            "Unable to guess where this is. Try another picture.",
            pickImageFrom);
        setState(() {
          isloading = false;
        });
        return;
      }
      geminiReply = value.text;
      List<String> replyList = geminiReply.split("#");
      countrytitle = replyList[0];
      replyList.removeAt(0);
      dataString = replyList;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                GeneratePage()), //directs the user to the information page
      );
      setState(() {
        isloading = false;
      });
      return;
    }).onError((error, stackTrace) {
      showErrorSnackbar(context, error.toString(), pickImageFrom);
      setState(() {
        isloading = false;
      });
      return;
    });
  }
}

//shows a message at the bottom of the screen.
void showSnackbar(
  BuildContext context,
  String message,
) {
  final snackBar = SnackBar(
    content: Text(message),
  );
  // Find the ScaffoldMessenger in the widget tree
  // and use it to show a SnackBar.
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

//shows a message at the bottom of the screen, along with an option to retry uploading a picture
void showErrorSnackbar(
    BuildContext context, String message, Function retryFunction) {
  final snackBar = SnackBar(
    content: Text(message),
    action: SnackBarAction(
      label: "RETRY",
      onPressed: () => retryFunction(true),
    ),
  );
  // Find the ScaffoldMessenger in the widget tree
  // and use it to show a SnackBar.
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

//!INFORMATION SCREEN //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

List<String> titleString = [
  "General Info",
  "Language",
  "How To Get There",
  "Exchange Rate",
  "Weather",
  "Famous Dishes"
];

const String oneShotPrompt = '''
where is this? try your best and if you cannot do it, strictly ONLY reply with 'NO'. 
reply in this format: location,country#tell me briefly about this place#language#how to get there from Singapore#currency, local currency exchange rate from Singapore dollars#what's the weather like there, please do not give me a link#famous dishes in that location
''';

String countrytitle = "???";
List<String> dataString = [];
File imageNotNull = File("");
String itinerary = "";
int itineraryDays = 7;

//New Page
class GeneratePage extends StatefulWidget {
  const GeneratePage({super.key});

  @override
  State<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends State<GeneratePage> {
  bool itineraryLoading = false;

  @override
  void initState() {
    itinerary = "";
    super.initState();
    createItinerary();
  }

  void refreshItinerary() {
    itinerary = "";
    showSnackbar(context, "Refreshing itinerary");
    setState(() {});
    createItinerary();
  }

  void createItinerary() async {
    setState(() {
      itineraryLoading = true;
    });
    String query =
        "Create a $itineraryDays-day itinerary for $countrytitle, as detailed as possble. DO NOT give me in Markdown, but rather use a hyphen for each activity.";
    gemini.generateFromText(query).then((value) {
      itinerary = value.text;
      setState(() {
        itineraryLoading = false;
      });
      return;
    }).onError((error, stackTrace) {
      showSnackbar(context, "Unable to create itinerary. Try again.");
      setState(() {
        itineraryLoading = false;
      });
      return;
    });
  }

  Widget fetchItineraryWidget() {
    return itinerary != ""
        ? Container(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                const Divider(
                  color: Color.fromARGB(255, 255, 157, 157),
                  thickness: 2.5,
                  indent: 30.0,
                  endIndent: 30.0,
                ),
                ListTile(
                  title: Text(
                    "$itineraryDays-day Itinerary",
                    style: TextStyle(color: darkerMainColor, fontSize: 30.0),
                  ),
                  subtitle: Text(
                    itinerary,
                    style: TextStyle(
                      color: darkerMainColor,
                      fontSize: 19.0,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Text("Generating itinerary",
                      style: TextStyle(fontSize: 20, color: mainColor)),
                  const SizedBox(height: 10),
                  CircularProgressIndicator(
                    color: mainColor,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lighterMainColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: mainColor,
        title: Text(
          countrytitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.file(
              imageNotNull, // Replace with the path to your image file
              fit: BoxFit.fitHeight, // Adjust the BoxFit property as needed
            ),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              scrollDirection: Axis.vertical,
              itemCount: dataString.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: Column(
                    children: <Widget>[
                      const Divider(
                        color: Color.fromARGB(255, 255, 157, 157),
                        thickness: 2.5,
                        indent: 30.0,
                        endIndent: 30.0,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Column(
                          children: <Widget>[
                            ListTile(
                              title: Text(
                                titleString[index],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 20.0),
                              ),
                              subtitle: Text(
                                dataString[index],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            fetchItineraryWidget(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          refreshItinerary();
        },
        backgroundColor: secondaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
