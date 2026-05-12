import 'dart:async';
import 'dart:io';

const String supabaseUrl = 'https://dolvpgqelmptgbvdugig.supabase.co';
const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRvbHZwZ3FlbG1wdGdidmR1Z2lnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTA2MTAsImV4cCI6MjA4ODU4NjYxMH0.f2HzYF5S1IwMN2cLPEC8F1jMUcLetAGUMUD6rqM1QT8';

Future<void> main() async {
  print('=== Supabase Yük Testi Başlıyor ===');
  
  // Test konfigürasyonu
  final int totalBots = 1000; // Aynı anda istek atacak bot sayısı
  final int requestsPerBot = 10; // Her botun atacağı istek sayısı
  
  int successfulRequests = 0;
  int failedRequests = 0;
  
  final client = HttpClient();
  
  // Performansı artırmak için connection sayısını sınırlayabiliriz
  client.maxConnectionsPerHost = 200;

  final endpoints = [
    '/rest/v1/profiles?select=*&limit=20',
    '/rest/v1/venues?select=*',
    '/rest/v1/events?select=*',
  ];

  Future<void> runBot(int botId) async {
    for (int i = 0; i < requestsPerBot; i++) {
      final endpoint = endpoints[i % endpoints.length];
      try {
        final request = await client.getUrl(Uri.parse('$supabaseUrl$endpoint'));
        request.headers.add('apikey', anonKey);
        request.headers.add('Authorization', 'Bearer $anonKey');
        
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          successfulRequests++;
        } else {
          failedRequests++;
          print('Bot $botId: Hata ${response.statusCode} - $endpoint');
        }
        await response.drain(); // Response'u tüketmek önemli
      } catch (e) {
        failedRequests++;
        print('Bot $botId: Exception - $e');
      }
      
      // İstekler arası çok kısa bekleme
      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  print('$totalBots bot, her biri $requestsPerBot istek atacak. Toplam ${totalBots * requestsPerBot} istek bekleniyor...');
  final stopwatch = Stopwatch()..start();
  
  List<Future<void>> botFutures = [];
  for (int i = 0; i < totalBots; i++) {
    botFutures.add(runBot(i));
  }
  
  await Future.wait(botFutures);
  stopwatch.stop();
  client.close();
  
  final totalRequests = successfulRequests + failedRequests;
  final rps = (totalRequests / stopwatch.elapsedMilliseconds * 1000).toStringAsFixed(2);

  print('\n=== Test Sonuçları ===');
  print('Geçen Süre: ${stopwatch.elapsedMilliseconds} ms');
  print('Başarılı İstekler: $successfulRequests');
  print('Başarısız İstekler: $failedRequests');
  print('Saniyede İstek (RPS): $rps req/sec');
}
