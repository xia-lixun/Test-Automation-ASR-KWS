#pragma once
#include <stdint.h>


#if defined(PA_DYNAMIC_EXPORT) // inside DLL
	#define PA_DYNAMIC_API   __declspec(dllexport)
#else // outside DLL
	#define PA_DYNAMIC_API   __declspec(dllimport)
#endif  // XYZLIBRARY_EXPORT




extern "C" PA_DYNAMIC_API int play(const float * pcm_play, int64_t play_channels, int64_t play_frames, int64_t samplerate);
extern "C" PA_DYNAMIC_API int record(float * pcm_record, int64_t record_channels, int64_t record_frames, int64_t samplerate);
extern "C" PA_DYNAMIC_API int playrecord(const float * pcm_play, int64_t play_channels, float * pcm_record, int64_t record_channels, int64_t common_frames, int64_t samplerate);
extern "C" PA_DYNAMIC_API int list_devices(char * ld);