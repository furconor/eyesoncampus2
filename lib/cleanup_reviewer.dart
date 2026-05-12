import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final client = Supabase.instance.client;

  print('Starting DB Cleanup for Apple Reviewer...');

  try {
    // 1. Get reviewer and Zeynep IDs
    final reviewer = await client.from('profiles').select('id').eq('name', 'Apple Reviewer').maybeSingle();
    final zeynep = await client.from('profiles').select('id').eq('name', 'Zeynep K.').maybeSingle();

    if (reviewer == null || zeynep == null) {
      print('Could not find Reviewer or Zeynep in DB.');
      return;
    }

    final rId = reviewer['id'];
    final zId = zeynep['id'];

    print('Reviewer ID: $rId');
    print('Zeynep ID: $zId');

    // 2. Delete swipes
    print('Cleaning up swipes...');
    await client.from('swipes').delete().eq('sender_id', rId).neq('receiver_id', zId);
    await client.from('swipes').delete().eq('receiver_id', rId).neq('sender_id', zId);

    // 3. Get matches involving Reviewer BUT NOT Zeynep
    print('Finding matches to delete...');
    final matchesToDelete = await client
        .from('matches')
        .select('id')
        .or('user1_id.eq.$rId,user2_id.eq.$rId')
        .not('user1_id', 'eq', zId)
        .not('user2_id', 'eq', zId);

    print('Found ${matchesToDelete.length} matches to delete.');

    for (var match in matchesToDelete) {
      final matchId = match['id'];
      
      // Delete conversations for this match (messages delete by cascade)
      await client.from('conversations').delete().eq('match_id', matchId);
      
      // Delete the match itself
      await client.from('matches').delete().eq('id', matchId);
      print('Deleted match $matchId');
    }

    print('Cleanup complete! Apple Reviewer state is reset, Zeynep match remains.');
  } catch (e) {
    print('Error during cleanup: $e');
  }
}
