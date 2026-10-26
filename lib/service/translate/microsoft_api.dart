import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/service/translate/official_api.dart';

class MicrosoftApiTranslateProvider extends OfficialApiTranslateProvider {
  MicrosoftApiTranslateProvider() : super(TranslateService.microsoftApi);
}
