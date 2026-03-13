import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';

class RoomService {
  final SupabaseClient _client;
  RoomService(this._client);

  Future<List<Room>> getAll() async {
    final data = await _client.from('rooms').select().order('name');
    return (data as List).map((e) => Room.fromJson(e)).toList();
  }
}
