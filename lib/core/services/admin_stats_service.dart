import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AdminStats {
  final int users;
  final int academicLevels;
  final int modules;

  // Main lectures
  final int lectures;
  final int publishedLectures;

  // Files
  final int files;
  final int pdfFiles;
  final int audioFiles;
  final int videoFiles;

  const AdminStats({
    required this.users,
    required this.academicLevels,
    required this.modules,
    required this.lectures,
    required this.publishedLectures,
    required this.files,
    required this.pdfFiles,
    required this.audioFiles,
    required this.videoFiles,
  });
}

class AdminStatsService {
  final SupabaseClient _supabase;

  AdminStatsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<AdminStats> getStats() async {
  final currentUser = _supabase.auth.currentUser;

  debugPrint('AUTH USER ID = ${currentUser?.id}');
  debugPrint('AUTH EMAIL = ${currentUser?.email}');

  final usersResponse = await _supabase
      .from('profiles')
      .select('id');

  debugPrint('PROFILES COUNT = ${usersResponse.length}');
  debugPrint('PROFILES DATA = $usersResponse');

  // باقي الكود كما هو...
    // ==============================================================
    // ACADEMIC LEVELS
    // Source: academic_levels
    // Only active levels
    // ==============================================================

    final levelsResponse = await _supabase
        .from('academic_levels')
        .select('id')
        .eq('is_active', true);

    // ==============================================================
    // MODULES
    // Source: modules
    // Only active modules
    // ==============================================================

    final modulesResponse = await _supabase
        .from('modules')
        .select('id')
        .eq('is_active', true);

    // ==============================================================
    // MAIN LECTURES
    // Source: lectures
    //
    // IMPORTANT:
    // A lecture is counted as ONE main lecture.
    // Files attached to it are NOT counted as lectures.
    // ==============================================================

    final lecturesResponse = await _supabase
        .from('lectures')
        .select('id, is_published')
        .eq('is_active', true);

    final publishedLectures = lecturesResponse
        .where((lecture) => lecture['is_published'] == true)
        .length;

    // ==============================================================
    // LECTURE FILES
    // Source: lecture_files
    //
    // This is the ONLY source used for file statistics.
    // We do NOT count lectures.pdf_path/audio_path/video_path here
    // to avoid double counting.
    // ==============================================================

    final filesResponse = await _supabase
        .from('lecture_files')
        .select('id, file_type')
        .eq('is_active', true);

    // ==============================================================
    // FILE TYPE COUNTERS
    // ==============================================================

    int pdfFiles = 0;
    int audioFiles = 0;
    int videoFiles = 0;

    for (final file in filesResponse) {
      final type = (file['file_type'] as String?)?.trim().toLowerCase() ?? '';

      switch (type) {
        case 'pdf':
          pdfFiles++;
          break;

        case 'audio':
          audioFiles++;
          break;

        case 'video':
          videoFiles++;
          break;
      }
    }

    // ==============================================================
    // RETURN STATISTICS
    // ==============================================================

    return AdminStats(
      users: usersResponse.length,
      academicLevels: levelsResponse.length,
      modules: modulesResponse.length,

      // Main lectures only.
      lectures: lecturesResponse.length,

      // Published main lectures.
      publishedLectures: publishedLectures,

      // Total active files.
      files: filesResponse.length,

      // File types.
      pdfFiles: pdfFiles,
      audioFiles: audioFiles,
      videoFiles: videoFiles,
    );
  }
}
