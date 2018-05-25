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
#include "PaTask.h"

#include <windows.h>



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







/** @file pa_devs.c
@ingroup examples_src
@brief List available devices, including device information.
@author Phil Burk http://www.softsynth.com

@note Define PA_USE_ASIO=0 to compile this code on Windows without
ASIO support.
*/
/*
* $Id$
*
* This program uses the PortAudio Portable Audio Library.
* For more information see: http://www.portaudio.com
* Copyright (c) 1999-2000 Ross Bencina and Phil Burk
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files
* (the "Software"), to deal in the Software without restriction,
* including without limitation the rights to use, copy, modify, merge,
* publish, distribute, sublicense, and/or sell copies of the Software,
* and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
* ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
* CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
* WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
* The text above constitutes the entire PortAudio license; however,
* the PortAudio community also makes the following non-binding requests:
*
* Any person wishing to distribute modifications to the Software is
* requested to send the modifications to the original developer so that
* they can be incorporated into the canonical version. It is also
* requested that these non-binding requests be included along with the
* license above.
*/




#define PA_USE_ASIO 1


/*******************************************************************/
static void PrintSupportedStandardSampleRates(
	const PaStreamParameters *inputParameters,
	const PaStreamParameters *outputParameters)
{
	static double standardSampleRates[] = {
		8000.0, 9600.0, 11025.0, 12000.0, 16000.0, 22050.0, 24000.0, 32000.0,
		44100.0, 48000.0, 88200.0, 96000.0, 192000.0, -1 /* negative terminated  list */
	};
	int     i, printCount;
	PaError err;

	printCount = 0;
	for (i = 0; standardSampleRates[i] > 0; i++)
	{
		err = Pa_IsFormatSupported(inputParameters, outputParameters, standardSampleRates[i]);
		if (err == paFormatIsSupported)
		{
			if (printCount == 0)
			{
				printf("\t%8.2f", standardSampleRates[i]);
				printCount = 1;
			}
			else if (printCount == 4)
			{
				printf(",\n\t%8.2f", standardSampleRates[i]);
				printCount = 1;
			}
			else
			{
				printf(", %8.2f", standardSampleRates[i]);
				++printCount;
			}
		}
	}
	if (!printCount)
		printf("None\n");
	else
		printf("\n");
}

/*******************************************************************/
int list_devices(char * ld)
{
	int     i, numDevices, defaultDisplayed;
	const   PaDeviceInfo *deviceInfo;
	PaStreamParameters inputParameters, outputParameters;
	PaError err;
	int nb = 0;

	err = Pa_Initialize();
	if (err != paNoError)
	{
		int nb = sprintf(ld, "ERROR: Pa_Initialize returned 0x%x\n", err);
		ld += nb;
		goto error;
	}

	//printf( "PortAudio version: 0x%08X\n", Pa_GetVersion());
	//printf( "Version text: '%s'\n", Pa_GetVersionInfo()->versionText );

	numDevices = Pa_GetDeviceCount();
	if (numDevices < 0)
	{
		nb = sprintf(ld, "ERROR: Pa_GetDeviceCount returned 0x%x\n", numDevices);
		ld += nb;
		err = numDevices;
		goto error;
	}
	nb = sprintf(ld, "Number of devices = %d\n", numDevices);
	ld += nb;
	for (i = 0; i<numDevices; i++)
	{
		deviceInfo = Pa_GetDeviceInfo(i);
		nb = sprintf(ld, "--------------------------------------- device #%d\n", i);
		ld += nb;

		/* Mark global and API specific default devices */
		defaultDisplayed = 0;
		if (i == Pa_GetDefaultInputDevice())
		{
			nb = sprintf(ld, "[ Default Input");
			ld += nb;
			defaultDisplayed = 1;
		}
		else if (i == Pa_GetHostApiInfo(deviceInfo->hostApi)->defaultInputDevice)
		{
			const PaHostApiInfo *hostInfo = Pa_GetHostApiInfo(deviceInfo->hostApi);
			nb = sprintf(ld, "[ Default %s Input", hostInfo->name);
			ld += nb;
			defaultDisplayed = 1;
		}

		if (i == Pa_GetDefaultOutputDevice())
		{
			nb = sprintf(ld,(defaultDisplayed ? "," : "["));
			ld += nb;
			nb = sprintf(ld, " Default Output");
			ld += nb;
			defaultDisplayed = 1;
		}
		else if (i == Pa_GetHostApiInfo(deviceInfo->hostApi)->defaultOutputDevice)
		{
			const PaHostApiInfo *hostInfo = Pa_GetHostApiInfo(deviceInfo->hostApi);
			nb = sprintf(ld, (defaultDisplayed ? "," : "["));
			ld += nb;
			nb = sprintf(ld, " Default %s Output", hostInfo->name);
			ld += nb;
			defaultDisplayed = 1;
		}

		if (defaultDisplayed) {
			nb = sprintf(ld, " ]\n");
			ld += nb;
		}

		/* print device info fields */
#ifdef WIN32
		//{   /* Use wide char on windows, so we can show UTF-8 encoded device names */
		//	wchar_t wideName[MAX_PATH];
		//	MultiByteToWideChar(CP_UTF8, 0, deviceInfo->name, -1, wideName, MAX_PATH - 1);
		//	wprintf(L"Name                        = %s\n", wideName);
		//}
#else
		//printf("Name                        = %s\n", deviceInfo->name);
#endif
		nb = sprintf(ld, "Name                        = %s\n", deviceInfo->name); ld += nb;
		nb = sprintf(ld, "Host API                    = %s\n", Pa_GetHostApiInfo(deviceInfo->hostApi)->name); ld += nb;
		nb = sprintf(ld, "Max inputs = %d", deviceInfo->maxInputChannels); ld += nb;
		nb = sprintf(ld, ", Max outputs = %d\n", deviceInfo->maxOutputChannels); ld += nb;

		nb = sprintf(ld, "Default low input latency   = %8.4f\n", deviceInfo->defaultLowInputLatency); ld += nb;
		nb = sprintf(ld, "Default low output latency  = %8.4f\n", deviceInfo->defaultLowOutputLatency); ld += nb;
		nb = sprintf(ld, "Default high input latency  = %8.4f\n", deviceInfo->defaultHighInputLatency); ld += nb;
		nb = sprintf(ld, "Default high output latency = %8.4f\n", deviceInfo->defaultHighOutputLatency); ld += nb;

#ifdef WIN32
#if PA_USE_ASIO
		/* ASIO specific latency information */
		if (Pa_GetHostApiInfo(deviceInfo->hostApi)->type == paASIO) {
			long minLatency, maxLatency, preferredLatency, granularity;

			err = PaAsio_GetAvailableLatencyValues(i,
				&minLatency, &maxLatency, &preferredLatency, &granularity);

			nb = sprintf(ld, "ASIO minimum buffer size    = %ld\n", minLatency); ld += nb;
			nb = sprintf(ld, "ASIO maximum buffer size    = %ld\n", maxLatency); ld += nb;
			nb = sprintf(ld, "ASIO preferred buffer size  = %ld\n", preferredLatency); ld += nb;

			if (granularity == -1) {
				nb = sprintf(ld, "ASIO buffer granularity     = power of 2\n"); ld += nb;
			}
			else {
				nb = sprintf(ld, "ASIO buffer granularity     = %ld\n", granularity); ld += nb;
			}
		}
#endif /* PA_USE_ASIO */
#endif /* WIN32 */

		nb = sprintf(ld, "Default sample rate         = %8.2f\n", deviceInfo->defaultSampleRate);
		ld += nb;

		/* poll for standard sample rates */
		inputParameters.device = i;
		inputParameters.channelCount = deviceInfo->maxInputChannels;
		inputParameters.sampleFormat = paInt16;
		inputParameters.suggestedLatency = 0; /* ignored by Pa_IsFormatSupported() */
		inputParameters.hostApiSpecificStreamInfo = NULL;

		outputParameters.device = i;
		outputParameters.channelCount = deviceInfo->maxOutputChannels;
		outputParameters.sampleFormat = paInt16;
		outputParameters.suggestedLatency = 0; /* ignored by Pa_IsFormatSupported() */
		outputParameters.hostApiSpecificStreamInfo = NULL;

		if (inputParameters.channelCount > 0)
		{
			nb = sprintf(ld, "Supported standard sample rates\n for half-duplex 16 bit %d channel input = \n",
				inputParameters.channelCount);
			ld += nb;
			PrintSupportedStandardSampleRates(&inputParameters, NULL);
		}

		if (outputParameters.channelCount > 0)
		{
			nb = sprintf(ld, "Supported standard sample rates\n for half-duplex 16 bit %d channel output = \n",
				outputParameters.channelCount);
			ld += nb;
			PrintSupportedStandardSampleRates(NULL, &outputParameters);
		}

		if (inputParameters.channelCount > 0 && outputParameters.channelCount > 0)
		{
			nb = sprintf(ld, "Supported standard sample rates\n for full-duplex 16 bit %d channel input, %d channel output = \n",
				inputParameters.channelCount, outputParameters.channelCount);
			ld += nb;
			PrintSupportedStandardSampleRates(&inputParameters, &outputParameters);
		}
	}

	Pa_Terminate();

	nb = sprintf(ld,"----------------------------------------------\n"); 
	ld += nb;
	return numDevices;

error:
	Pa_Terminate();
	nb = sprintf(ld, "Error number: %d\n", err); ld += nb;
	nb = sprintf(ld, "Error message: %s\n", Pa_GetErrorText(err)); ld += nb;
	return -1;
}
