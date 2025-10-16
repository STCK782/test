import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  String? domain = dotenv.env['KINTONE_DOMAIN'];
  String? baseUrl = dotenv.env['KINTONE_BASE_URL'];
  String? apiToken = dotenv.env['KINTONE_APITOKEN'];
  String? id = dotenv.env['KINTONE_ID'];
}
