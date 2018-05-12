#include <cstdio>
#include <cstdlib>
#include <string>

#include "PaTask.h"





// pa --play foo.wav --rate 48000 
// pa --record bar.wav --rate 48000 --channels 4 --duration 4.5 --bits 24
// pa --play foo.wav --record bar.wav --rate 48000 --channels 4 --bits 24
int main(int argc, char* argv[])
{
	//--play     foo.wav
	//--record   bar.wav
	//--rate     48000
	//--channels 4
	//--duration 4.5
	//--bits     24
	bool is_play = false;
	bool is_record = false;

	const char * path_play = "";
	const char * path_record = "";
	int rate = 0;
	int channels = 0;
	double duration = 0.0;
	int bits = 0;

	for (int i = 1; i < argc; i++)
	{
		if (strcmp(argv[i], "--play") == 0)
		{
			is_play = true;
			path_play = argv[i + 1];
		}

		if (strcmp(argv[i], "--record") == 0)
		{
			is_record = true;
			path_record = argv[i + 1];
		}
		
		if (strcmp(argv[i], "--rate") == 0)
		{
			rate = atoi(argv[i + 1]);
		}

		if (strcmp(argv[i], "--channels") == 0)
		{
			channels = atoi(argv[i + 1]);
		}

		if (strcmp(argv[i], "--duration") == 0)
		{
			duration = atof(argv[i + 1]);
		}

		if (strcmp(argv[i], "--bits") == 0)
		{
			bits = atoi(argv[i + 1]);
		}

	}

	printf("path_play = %s\n", path_play);
	printf("path_record = %s\n", path_record);
	printf("rate = %d\n", rate);
	printf("channels = %d\n", channels);
	printf("duration = %f\n", duration);
	printf("bits = %d\n", bits);

	if(is_play && (!is_record))
		return play(path_play, rate);
	else if((!is_play) && is_record)
		return record(path_record, rate, channels, duration, bits);
	else if(is_play && is_record)
		return playrecord(path_play, path_record, rate, channels, bits);
	else
		return -1;
}