import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
  });

  static const String eulaContentEn = """
EYESONCAMPUS - END USER LICENSE AGREEMENT (EULA)

1. Acceptance: By using this application, you agree to the terms of this agreement.

2. Objectionable Content: There is zero tolerance for objectionable content or abusive users. Any content that violates community guidelines (harassment, hate speech, etc.) will be removed within 24 hours.

3. Abusive Users: Users who violate these terms will be immediately and permanently banned from the platform.

4. Security: Features to report and block other users are active and required for platform use.

5. Disclaimer: The application is provided "as is". It is recommended to follow basic safety rules during on-campus interactions.

Last updated: March 2026
""";

  static const String privacyContentEn = """
PRIVACY POLICY

1. Data Collection: We only collect email, name, and campus zone information necessary to create your profile and provide matching.

2. Location Information: Your location is not shared as exact coordinates; it is only shown to other users based on your selected campus zone (e.g., Central Cafe).

3. Data Sharing: Your data is not shared with third parties for advertising or marketing purposes.

4. Account Deletion: When you delete your account, all your messages and profile information are permanently removed from our database.

5. Security: Your data is stored encrypted with Supabase infrastructure.

Last updated: March 2026
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title.toUpperCase(), 
          style: const TextStyle(
            fontFamily: 'Space Mono', 
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppTheme.text,
          )
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface3.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border.withOpacity(0.5)),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: AppTheme.text.withOpacity(0.9),
                fontSize: 13,
                height: 1.8,
                fontFamily: 'Space Mono',
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const String eulaContent = """
EYESONCAMPUS - SON KULLANICI LİSANS SÖZLEŞMESİ (EULA)

1. Kabul: Bu uygulamayı kullanarak, bu sözleşme şartlarını kabul etmiş sayılırsınız.

2. Uygunsuz İçerik: EyesOnCampus, uygunsuz içerik ve tacizci kullanıcılara karşı sıfır tolerans politikası izler. Topluluk kurallarını ihlal eden içerikler 24 saat içinde sistemden kaldırılacaktır.

3. Kullanıcı Banlama: Kuralları ihlal eden veya tacizci davranış sergileyen kullanıcılar, platformdan kalıcı olarak ve derhal uzaklaştırılacaktır.

4. Güvenlik: Diğer kullanıcıları bildirme (report) ve engelleme (block) özellikleri tüm kullanıcılar için zorunlu ve aktiftir.

5. Sorumluluk Reddi: Uygulama "olduğu gibi" sunulmaktadır. Kampüs içi etkileşimlerde temel güvenlik kurallarına uymanız önerilir.

Son güncelleme: Mart 2026
""";

  static const String privacyContent = """
GİZLİLİK POLİTİKASI

1. Veri Toplama: Sadece profilinizi oluşturmak ve eşleşme sağlamak için gerekli olan e-posta, isim ve kampüs bölgesi bilgilerini topluyoruz.

2. Konum Bilgisi: Konumunuz tam koordinat olarak paylaşılmaz; sadece seçtiğiniz kampüs bölgesi (örn: Merkez Kafe) bazında diğer kullanıcılara gösterilir.

3. Veri Paylaşımı: Verileriniz üçüncü şahıslarla reklam veya pazarlama amacıyla paylaşılmaz.

4. Hesap Silme: Hesabınızı sildiğinizde, tüm mesajlarınız ve profil bilgileriniz veritabanımızdan kalıcı olarak temizlenir.

5. Güvenlik: Verileriniz Supabase altyapısı ile şifrelenmiş olarak saklanmaktadır.

Son güncelleme: Mart 2026
""";
}
