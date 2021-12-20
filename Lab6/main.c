#include <stdio.h>
#include <windows.h>
#include <time.h>
#include <stdbool.h>

#define THREADS_NUMBER 3
#define ITERATIONS 10

unsigned int active_readers = 0;
bool active_writer = false;
HANDLE can_read;
HANDLE can_write;

HANDLE hMutex;
//unsigned int readers_queue = 0;
//unsigned int writers_queue = 0;

int value = 0;

struct params
{
    int id;
    int delay;
};

void start_read()
{
    //WaitForSingleObject(hMutex, INFINITE);
    if (active_writer || WaitForSingleObject(can_write, 0) == WAIT_OBJECT_0)
        WaitForSingleObject(can_read, INFINITE);
    active_readers++;
    SetEvent(can_read);
}

void stop_read()
{
    active_readers--;
    if (active_readers == 0)
        SetEvent(can_write);
}

DWORD WINAPI reader(CONST LPVOID lpParams)
{
    struct params *r = lpParams;
    int r_id = r->id; //(int)(lpParams);
    int delay = r->delay; //(int)(lpParams+sizeof(int)); //rand() % 3000 + 1000;
    printf("Reader %d delay = %d\n", r_id, delay);
    for (int j = 0; j < ITERATIONS; j++)
    {
        Sleep(delay);

        start_read();

        //printf("Reader %d started reading\n", r_id);

        printf("Reader %d have read: %d\n", r_id, value);

        stop_read();

        //printf("Reader %d stoped reading\n", r_id);
    }

    return 0;
}

void start_write()
{
    if (active_readers > 0 || active_writer)
        WaitForSingleObject(can_write, INFINITE);
    active_writer = true;
}

void stop_write()
{
    active_writer = false;
    if (WaitForSingleObject(can_read, 0) == WAIT_OBJECT_0)
        SetEvent(can_read);
    else
        SetEvent(can_write);
}

DWORD WINAPI writer(CONST LPVOID lpParams)
{
    struct params *w = lpParams;
    int w_id = w->id; //(int)(lpParams);
    int delay = w->delay; //(int)(lpParams+sizeof(int)); //rand() % 3000 + 1000;
    printf("Writer %d delay = %d\n", w_id, delay);
    for (int j = 0; j < ITERATIONS; j++)
    {
        Sleep(delay);

        start_write();

        //printf("Writer %d started writing\n", w_id);

        printf("Writer %d have written: %d\n", w_id, ++value);

        stop_write();

        //printf("Writer %d stoped writing\n", w_id);
    }

    return 0;
}

int main()
{
    srand(time(NULL));
    can_read = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (NULL == can_read)
        perror("Failed to create event can_read");

    can_write = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (NULL == can_write)
        perror("Failed to create event can_write");

    hMutex = CreateMutex(NULL, FALSE, NULL);
    if (NULL == hMutex)
        perror("Failed to create mutex");

    HANDLE hReaders[THREADS_NUMBER];
    HANDLE hWriters[THREADS_NUMBER];

    for (int i = 0; i < THREADS_NUMBER; i++)
    {
        struct params r = {i+1, rand()%3000+1000};
        //printf("Reader %d delay = %d\n", r.id, r.delay);
        hReaders[i] = CreateThread(NULL, 0, &reader, &r, 0, NULL);
        struct params w = {i+1, rand()%3000+1000};
        //printf("Writer %d delay = %d\n", w.id, w.delay);
        hWriters[i] = CreateThread(NULL, 0, &writer, &w, 0, NULL);
        //createChild(i+1, &reader);
        //createChild(i+1, &writer);
    }

    WaitForMultipleObjects(THREADS_NUMBER, hReaders, TRUE, INFINITE);
    WaitForMultipleObjects(THREADS_NUMBER, hWriters, TRUE, INFINITE);

    for (int i = 0; i < THREADS_NUMBER; i++)
    {
        CloseHandle(hReaders[i]);
        CloseHandle(hWriters[i]);
    }
    CloseHandle(hMutex);
    CloseHandle(can_read);
    CloseHandle(can_write);


    printf("EXIT_SUCCESS = %d", EXIT_SUCCESS);
    return 0;
}
