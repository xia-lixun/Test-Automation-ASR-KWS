/** @file PaTask.cpp
	@ingroup PaDynamic
	@brief Portaudio wrapper for dynamic languages: Julia/Matlab etc.
	@author Lixun Xia <lixun.xia2@harman.com>
*/

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <string>
#include <cassert>
#include "../include/portaudio.h"
#include "../include/pa_asio.h"
#include "./PaTask.h"


#define FRAMES_PER_BUFFER	(64)




class PaPlayRecord
{
public:
	PaPlayRecord(
		const float * pcm_play,
		int64_t play_channels,
		float * pcm_record,
		int64_t record_channels,
		int64_t common_frames,
		int64_t samplerate

	) : stream(0), in_framecount(0), out_framecount(0)
	{
		fs = samplerate;
		pcm_out = pcm_play;
		pcm_in = pcm_record;
		out_ch = play_channels;
		in_ch = record_channels;
		frames = common_frames;
		out_samples = frames * out_ch;

		sprintf(message, "PaPlayRecord ctor ok");
	}


	bool open(PaDeviceIndex index)
	{
		PaStreamParameters inputParameters;
		PaStreamParameters outputParameters;

		inputParameters.device = index;
		outputParameters.device = index;

		if (outputParameters.device == paNoDevice)
			return false;
		if (inputParameters.device == paNoDevice)
			return false;

		const PaDeviceInfo* pInfo = Pa_GetDeviceInfo(index);
		if (pInfo != 0)
			printf("Output device name: '%s'\r", pInfo->name);

		outputParameters.channelCount = (int)(out_ch);         
		outputParameters.sampleFormat = paFloat32;
		outputParameters.suggestedLatency = Pa_GetDeviceInfo(outputParameters.device)->defaultLowOutputLatency;
		outputParameters.hostApiSpecificStreamInfo = NULL;

		inputParameters.channelCount = (int)(in_ch);         
		inputParameters.sampleFormat = paFloat32;                   
		inputParameters.suggestedLatency = Pa_GetDeviceInfo(inputParameters.device)->defaultLowOutputLatency;
		inputParameters.hostApiSpecificStreamInfo = NULL;

		//frames per buffer can also be "paFramesPerBufferUnspecified"
		//Using 'this' for userData so we can cast to PaPlay* in paCallback method
		if (paNoError != Pa_OpenStream(&stream, &inputParameters, &outputParameters, fs, FRAMES_PER_BUFFER, paClipOff, &PaPlayRecord::paCallback, this))
			return false;
		if (paNoError != Pa_SetStreamFinishedCallback(stream, &PaPlayRecord::paStreamFinished))
		{
			Pa_CloseStream(stream);
			stream = 0;
			return false;
		}
		return true;
	}


	bool info()
	{
		if (stream == 0)
			return false;
		const PaStreamInfo * stream_info = Pa_GetStreamInfo(stream);
		printf("PaStreamInfo: struct version = %d\n", stream_info->structVersion);
		printf("PaStreamInfo: input latency = %f second\n", stream_info->inputLatency);
		printf("PaStreamInfo: output latency = %f second\n", stream_info->outputLatency);
		printf("PaStreamInfo: sample rate = %f sps\n", stream_info->sampleRate);
		return paNoError;
	}


	bool close()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_CloseStream(stream);
		stream = 0;
		return (err == paNoError);
	}

	bool start()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_StartStream(stream);
		return (err == paNoError);
	}

	bool pending()
	{
		if (stream == 0)
			return false;
		printf("\n");
		while (Pa_IsStreamActive(stream))
		{
			printf("\rcpu load:[%f], patime[%f]", cpuload, timebase); fflush(stdout);
			Pa_Sleep(500);
		}
		return paNoError;
	}

	bool stop()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_StopStream(stream);
		return (err == paNoError);
	}

	volatile double cpuload;
	volatile PaTime timebase;


private:
	/* The instance callback, where we have access to every method/variable in object of class PaPlay */
	int paCallbackMethod(
		const void *inputBuffer,
		void *outputBuffer,
		unsigned long framesPerBuffer,
		const PaStreamCallbackTimeInfo* timeInfo,
		PaStreamCallbackFlags statusFlags)
	{
		const float *in = (const float *)inputBuffer;
		float *out = (float*)outputBuffer;
		unsigned long i;

		(void)timeInfo; /* Prevent unused variable warnings. */
		(void)statusFlags;


		for (i = 0; i < framesPerBuffer; i++)
		{
			memcpy(out, &pcm_out[out_framecount], out_ch * sizeof(float));
			memcpy(pcm_in, in, in_ch * sizeof(float));

			out += out_ch;
			in += in_ch;

			out_framecount += out_ch;
			pcm_in += in_ch;
			in_framecount += 1; //for sentinel and verification only

			if (out_framecount >= out_samples)
			{
				assert(in_framecount == frames);
				memset(out, 0, (framesPerBuffer - i - 1) * out_ch * sizeof(float));
				out_framecount = 0;
				in_framecount = 0;
				return paComplete;
			}
		}

		//update utility features
		cpuload = Pa_GetStreamCpuLoad(stream);
		timebase = Pa_GetStreamTime(stream);

		return paContinue;
	}

	/* This routine will be called by the PortAudio engine when audio is needed.
	** It may called at interrupt level on some machines so don't do anything
	** that could mess up the system like calling malloc() or free().
	*/
	static int paCallback(
		const void *inputBuffer,
		void *outputBuffer,
		unsigned long framesPerBuffer,
		const PaStreamCallbackTimeInfo* timeInfo,
		PaStreamCallbackFlags statusFlags,
		void *userData)
	{
		/* Here we cast userData to PaPlay* type so we can call the instance method paCallbackMethod, we can do that since
		we called Pa_OpenStream with 'this' for userData */
		return ((PaPlayRecord*)userData)->paCallbackMethod(inputBuffer, outputBuffer, framesPerBuffer, timeInfo, statusFlags);
	}




	void paStreamFinishedMethod()
	{
		printf("Stream Completed: %s\n", message);
	}

	/*
	* This routine is called by portaudio when playback is done.
	*/
	static void paStreamFinished(void* userData)
	{
		return ((PaPlayRecord*)userData)->paStreamFinishedMethod();
	}

	size_t fs;
	size_t frames;
	size_t out_ch;
	size_t in_ch;
	size_t in_framecount;
	size_t out_framecount;
	size_t out_samples;
	float * pcm_in;
	const float * pcm_out;

	PaStream *stream;
	char message[20];
};





class PaRecord
{
public:
	PaRecord(
		float * pcm_record,
		int64_t record_channels,
		int64_t record_frames,
		int64_t samplerate
	) : stream(0), in_framecount(0)
	{
		fs = samplerate;
		frames = record_frames;
		in_ch = record_channels;
		pcm_in = pcm_record;
		sprintf(message, "PaRecord ctor ok");
	}


	bool open(PaDeviceIndex index)
	{
		PaStreamParameters inputParameters;
		inputParameters.device = index;
		if (inputParameters.device == paNoDevice)
			return false;
		const PaDeviceInfo* pInfo = Pa_GetDeviceInfo(index);
		if (pInfo != 0)
			printf("Output device name: '%s'\r", pInfo->name);

		inputParameters.channelCount = in_ch;       
		inputParameters.sampleFormat = paFloat32;                  
		inputParameters.suggestedLatency = Pa_GetDeviceInfo(inputParameters.device)->defaultLowOutputLatency;
		inputParameters.hostApiSpecificStreamInfo = NULL;

		//frames per buffer can also be "paFramesPerBufferUnspecified"
		//Using 'this' for userData so we can cast to PaPlay* in paCallback method
		if (paNoError != Pa_OpenStream(&stream, &inputParameters, NULL, fs, FRAMES_PER_BUFFER, paClipOff, &PaRecord::paCallback, this))
			return false;
		if (paNoError != Pa_SetStreamFinishedCallback(stream, &PaRecord::paStreamFinished))
		{
			Pa_CloseStream(stream);
			stream = 0;
			return false;
		}
		return true;
	}


	bool info()
	{
		if (stream == 0)
			return false;
		const PaStreamInfo * stream_info = Pa_GetStreamInfo(stream);
		printf("PaStreamInfo: struct version = %d\n", stream_info->structVersion);
		printf("PaStreamInfo: input latency = %f second\n", stream_info->inputLatency);
		printf("PaStreamInfo: output latency = %f second\n", stream_info->outputLatency);
		printf("PaStreamInfo: sample rate = %f sps\n", stream_info->sampleRate);
		return paNoError;
	}


	bool close()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_CloseStream(stream);
		stream = 0;
		return (err == paNoError);
	}

	bool start()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_StartStream(stream);
		return (err == paNoError);
	}

	bool pending()
	{
		if (stream == 0)
			return false;
		printf("\n");
		while (Pa_IsStreamActive(stream))
		{
			printf("\rcpu load:[%f], patime[%f]", cpuload, timebase); fflush(stdout);
			Pa_Sleep(500);
		}
		return paNoError;
	}

	bool stop()
	{
		if (stream == 0)
			return false;
		PaError err = Pa_StopStream(stream);
		return (err == paNoError);
	}

	volatile double cpuload;
	volatile PaTime timebase;


private:
	/* The instance callback, where we have access to every method/variable in object of class PaPlay */
	int paCallbackMethod(
		const void *inputBuffer,
		void *outputBuffer,
		unsigned long framesPerBuffer,
		const PaStreamCallbackTimeInfo* timeInfo,
		PaStreamCallbackFlags statusFlags)
	{
		const float *in = (const float *)inputBuffer;
		unsigned long i;

		(void)timeInfo; /* Prevent unused variable warnings. */
		(void)statusFlags;
		(void)outputBuffer;

		for (i = 0; i < framesPerBuffer; i++)
		{
			memcpy(pcm_in, in, in_ch * sizeof(float));
			
			in += in_ch;
			pcm_in += in_ch;
			in_framecount += 1;
			
			if (in_framecount >= frames)
			{
				in_framecount = 0;
				return paComplete;
			}
		}

		//update utility features
		cpuload = Pa_GetStreamCpuLoad(stream);
		timebase = Pa_GetStreamTime(stream);

		return paContinue;
	}

	/* This routine will be called by the PortAudio engine when audio is needed.
	** It may called at interrupt level on some machines so don't do anything
	** that could mess up the system like calling malloc() or free().
	*/
	static int paCallback(
		const void *inputBuffer,
		void *outputBuffer,
		unsigned long framesPerBuffer,
		const PaStreamCallbackTimeInfo* timeInfo,
		PaStreamCallbackFlags statusFlags,
		void *userData)
	{
		/* Here we cast userData to PaPlay* type so we can call the instance method paCallbackMethod, we can do that since
		we called Pa_OpenStream with 'this' for userData */
		return ((PaRecord*)userData)->paCallbackMethod(inputBuffer, outputBuffer, framesPerBuffer, timeInfo, statusFlags);
	}




	void paStreamFinishedMethod()
	{
		printf("Stream Completed: %s\n", message);
	}

	/*
	* This routine is called by portaudio when playback is done.
	*/
	static void paStreamFinished(void* userData)
	{
		return ((PaRecord*)userData)->paStreamFinishedMethod();
	}


	size_t fs;
	size_t frames;
	size_t in_ch;
	size_t in_framecount;
	float * pcm_in;

	PaStream *stream;
	char message[20];
};






class PaPlay
{
public:
    PaPlay(
		const float * pcm_play,
		int64_t play_channels,
		int64_t play_frames,
		int64_t samplerate
		) : stream(0), out_framecount(0)
    {
		fs = samplerate;
		frames = play_frames;
		out_ch = play_channels;
		out_samples = frames * out_ch;
		pcm_out = pcm_play;
        sprintf( message, "PaPlay ctor ok" );
    }


    bool open(PaDeviceIndex index)
    {
        PaStreamParameters outputParameters;
        outputParameters.device = index;
        if (outputParameters.device == paNoDevice)
            return false;
        const PaDeviceInfo* pInfo = Pa_GetDeviceInfo(index);
        if (pInfo != 0)
            printf("Output device name: '%s'\r", pInfo->name);

        outputParameters.channelCount = out_ch;         
        outputParameters.sampleFormat = paFloat32;                              
        outputParameters.suggestedLatency = Pa_GetDeviceInfo( outputParameters.device )->defaultLowOutputLatency;
        outputParameters.hostApiSpecificStreamInfo = NULL;

		/* Use an ASIO specific structure. WARNING - this is not portable. */
		//asioOutputInfo.size = sizeof(PaAsioStreamInfo);
		//asioOutputInfo.hostApiType = paASIO;
		//asioOutputInfo.version = 1;
		//asioOutputInfo.flags = paAsioUseChannelSelectors;
		////outputChannelSelectors[0] = 1; /* skip channel 0 and use the second (right) ASIO device channel */
		//asioOutputInfo.channelSelectors = outputChannelSelectors;
		//outputParameters.hostApiSpecificStreamInfo = &asioOutputInfo;


		//frames per buffer can also be "paFramesPerBufferUnspecified"
		//Using 'this' for userData so we can cast to PaPlay* in paCallback method
        if (paNoError != Pa_OpenStream(&stream, NULL, &outputParameters, fs, FRAMES_PER_BUFFER, paClipOff, &PaPlay::paCallback, this))
            return false;
        if (paNoError != Pa_SetStreamFinishedCallback(stream, &PaPlay::paStreamFinished))
        {
            Pa_CloseStream( stream );
            stream = 0;
            return false;
        }
        return true;
    }


	bool info()
	{
		if (stream == 0)
			return false;
		const PaStreamInfo * stream_info = Pa_GetStreamInfo(stream);
		printf("PaStreamInfo: struct version = %d\n", stream_info->structVersion);
		printf("PaStreamInfo: input latency = %f second\n", stream_info->inputLatency);
		printf("PaStreamInfo: output latency = %f second\n", stream_info->outputLatency);
		printf("PaStreamInfo: sample rate = %f sps\n", stream_info->sampleRate);
		return paNoError;
	}


    bool close()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_CloseStream( stream );
        stream = 0;
        return (err == paNoError);
    }

    bool start()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_StartStream( stream );
        return (err == paNoError);
    }

	bool pending()
	{
		if (stream == 0)
			return false;
		printf("\n");
		while (Pa_IsStreamActive(stream))
		{
			printf("\rcpu load:[%f], patime[%f]", cpuload, timebase); fflush(stdout);
			Pa_Sleep(500);
		}
		return paNoError;
	}

    bool stop()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_StopStream( stream );
        return (err == paNoError);
    }


	volatile double cpuload;
	volatile PaTime timebase;


private:
    /* The instance callback, where we have access to every method/variable in object of class PaPlay */
    int paCallbackMethod(
		const void *inputBuffer, 
		void *outputBuffer,
        unsigned long framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags)
    {
        float *out = (float*)outputBuffer;
        unsigned long i;

        (void) timeInfo; /* Prevent unused variable warnings. */
        (void) statusFlags;
        (void) inputBuffer;

        for( i = 0; i < framesPerBuffer; i++ )
        {
			memcpy(out, &pcm_out[out_framecount], out_ch * sizeof(float));
			out += out_ch;
			out_framecount += out_ch;
			if (out_framecount >= out_samples)
			{
				memset(out, 0, (framesPerBuffer-i-1) * out_ch * sizeof(float));
				out_framecount = 0;
				return paComplete;
			}
        }

		//update utility features
		cpuload = Pa_GetStreamCpuLoad(stream);
		timebase = Pa_GetStreamTime(stream);

        return paContinue;
    }

    /* This routine will be called by the PortAudio engine when audio is needed.
    ** It may called at interrupt level on some machines so don't do anything
    ** that could mess up the system like calling malloc() or free().
    */
    static int paCallback( 
		const void *inputBuffer, 
		void *outputBuffer,
        unsigned long framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags,
        void *userData )
    {
        /* Here we cast userData to PaPlay* type so we can call the instance method paCallbackMethod, we can do that since 
           we called Pa_OpenStream with 'this' for userData */
        return ((PaPlay*)userData)->paCallbackMethod(inputBuffer, outputBuffer, framesPerBuffer, timeInfo, statusFlags);
    }


    void paStreamFinishedMethod()
    {
        printf( "Stream Completed: %s\n", message );
    }

    /*
     * This routine is called by portaudio when playback is done.
     */
    static void paStreamFinished(void* userData)
    {
        return ((PaPlay*)userData)->paStreamFinishedMethod();
    }


	size_t fs;
	size_t frames;
	size_t out_ch;
	size_t out_framecount;
	size_t out_samples;
	const float * pcm_out;

	PaStream *stream;
    char message[20];
};




class ScopedPaHandler
{
public:
    ScopedPaHandler()
        : _result(Pa_Initialize())
    {
    }
    ~ScopedPaHandler()
    {
        if (_result == paNoError)
            Pa_Terminate();
    }

    PaError result() const { return _result; }

private:
    PaError _result;
};








//                        ----------------------
//                        --   DLL Interface  --
//                        ----------------------



int playrecord(const float * pcm_play, int64_t play_channels, float * pcm_record, int64_t record_channels, int64_t common_frames, int64_t samplerate)
{
	printf("PortAudio: sync play and record, fs = %lld, buffer = %d\n", samplerate, FRAMES_PER_BUFFER);
	
	PaPlayRecord PaPlayRecord(pcm_play, play_channels, pcm_record, record_channels, common_frames, samplerate);
	ScopedPaHandler paInit;

	if (paInit.result() != paNoError)
		goto error;

	if (PaPlayRecord.open(Pa_GetDefaultOutputDevice()))
	{
		PaPlayRecord.info();
		if (PaPlayRecord.start())
		{
			PaPlayRecord.pending();
			PaPlayRecord.stop();
		}
		PaPlayRecord.close();
	}
	return paNoError;

error:
	fprintf(stderr, "An error occured while using the portaudio stream\n");
	fprintf(stderr, "Error number: %d\n", paInit.result());
	fprintf(stderr, "Error message: %s\n", Pa_GetErrorText(paInit.result()));
	return 1;
}



int play(const float * pcm_play, int64_t play_channels, int64_t play_frames, int64_t samplerate)
{
	printf("PortAudio: playback, fs = %lld, buffer = %d\n", samplerate, FRAMES_PER_BUFFER);
    
	PaPlay PaPlay(pcm_play, play_channels, play_frames, samplerate);
	ScopedPaHandler paInit;

    if( paInit.result() != paNoError ) 
		goto error;

    if (PaPlay.open(Pa_GetDefaultOutputDevice()))
    {
		PaPlay.info();
        if (PaPlay.start())
        {    
			PaPlay.pending();
            PaPlay.stop();
        }
        PaPlay.close();
    }
    return paNoError;

error:
    fprintf( stderr, "An error occured while using the portaudio stream\n" );
    fprintf( stderr, "Error number: %d\n", paInit.result() );
    fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( paInit.result() ) );
    return 1;
}



int record(float * pcm_record, int64_t record_channels, int64_t record_frames, int64_t samplerate)
{
	printf("PortAudio: recording, fs = %lld, buffer = %d\n", samplerate, FRAMES_PER_BUFFER);
	
	PaRecord PaRecord(pcm_record, record_channels, record_frames, samplerate);
	ScopedPaHandler paInit;

	if (paInit.result() != paNoError)
		goto error;

	if (PaRecord.open(Pa_GetDefaultOutputDevice()))
	{
		PaRecord.info();
		if (PaRecord.start())
		{
			PaRecord.pending();
			PaRecord.stop();
		}
		PaRecord.close();
	}
	return paNoError;

error:
	fprintf(stderr, "An error occured while using the portaudio stream\n");
	fprintf(stderr, "Error number: %d\n", paInit.result());
	fprintf(stderr, "Error message: %s\n", Pa_GetErrorText(paInit.result()));
	return 1;
}