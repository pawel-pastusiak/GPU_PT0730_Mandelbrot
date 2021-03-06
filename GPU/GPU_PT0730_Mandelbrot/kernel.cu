
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <fstream>
#include <string>
#include <stdio.h>
#include <iostream>
#include <iomanip>
#include <time.h>
#include <windows.h>

using namespace std;


double PCFreq = 0.0;
__int64 CounterStart = 0;

void StartCounter()
{
    LARGE_INTEGER li;
    if (!QueryPerformanceFrequency(&li))
        cout << "QueryPerformanceFrequency failed!\n";

    PCFreq = double(li.QuadPart) / 1000.0;

    QueryPerformanceCounter(&li);
    CounterStart = li.QuadPart;
}
double GetCounter()
{
    LARGE_INTEGER li;
    QueryPerformanceCounter(&li);
    return double(li.QuadPart - CounterStart) / PCFreq;
}



__device__ void pointApproximation(float* realPart, float* imagPart, int* maxIter, int* approximation)
{
    *approximation = 0;
    int i = 0;
    float zReal = 0;
    float zImag = 0;
    float zTempReal = 0;
    float zTempImag = 0;

    while (i < *maxIter && (zReal * zReal + zImag * zImag < 4))
    {
        zTempReal = zReal * zReal - zImag * zImag;
        zTempImag = 2 * zReal * zImag;

        zReal = zTempReal + *realPart;
        zImag = zTempImag + *imagPart;


        i++;
    }
    
    *approximation = i;
}

__device__ void traverse(float startX, float startY, float endX, float endY, float* step, int* maxIter, int* approximation, float* width)
{
    int i = 0;
    float curX, curY;
    curY = startY;
    while (curY < endY) {
        int j = 0;
        curX = startX;
        while (curX < endX) {
            pointApproximation(&curX, &curY, maxIter, approximation + (i * (int)(*width / *step + 0.5)) + j++);
            curX += *step;
        }
        curY += *step;
        i++;
    } 
}

__global__ void Func(int* appro, float* step, int* maxIter, float* width, int* numberThreads, int size, float ratio)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < *numberThreads - 1)
        traverse(-2.0f, -2.0f + i**step, 2.0f, -2.0f + (i+1) * *step, step, maxIter, appro + (int)(size * size * i / ratio + 0.5), width);
    else if (i == *numberThreads - 1)
        traverse(-2.0f, -2.0f + i * *step + i, 2.0f, 2.0f, step, maxIter, appro + (int)(size * size * i / ratio + 0.5), width);
}

int main()
{
    int blocksize = 384;
    int max = 0;
    float step = 0;
    int numberThreads = 0;

    cout << "Prosze podac dokladnosc liczby zmiennoprzecinkowej: ";
    cin >> step;
    cout << "\nProsze podac maksymalna liczbe powtorzen funkcji sprawdzajacej przynaleznosc punktu do zbioru: ";
    cin >> max;
    //cout << "\nProsze podac liczbe watkow: ";
    //cin >> numberThreads;

    int deviceCount, device;
    int gpuDeviceCount = 0;
    struct cudaDeviceProp properties;
    cudaError_t cudaResultCode = cudaGetDeviceCount(&deviceCount);
    if (cudaResultCode != cudaSuccess)
        deviceCount = 0;
    for (device = 0; device < deviceCount; ++device) 
    {
        cudaGetDeviceProperties(&properties, device);
        //9999 means emulation only
        if (properties.major != 9999)
            if (device == 0)
            {
                numberThreads = properties.multiProcessorCount * properties.maxThreadsPerMultiProcessor;
                cout << numberThreads << endl;
            }
    }

    double ms = 0;
    StartCounter();

    float width = 4.0;
    int size = (int)((width / step) + 0.5);

    if (numberThreads > size)
        numberThreads = size;   //clamp(0,size)


    int* approximations;
    approximations = (int*)malloc(sizeof(int) * (size + 1) * (size + 1));

    int most_of_rectangles_height = size / numberThreads;

    //Most of the rectangles size ratio
    float most_of_rectangles_size_ratio = size / (float)most_of_rectangles_height;


    int* approximations_c;
    float* width_c;
    int* max_c;
    float* step_c;
    int* numberThreads_c;


    cudaMalloc((void**)&approximations_c, sizeof(int) * (size + 1) * (size + 1));

    cudaMalloc((void**)&width_c, sizeof(float));
    cudaMalloc((void**)&max_c, sizeof(int));
    cudaMalloc((void**)&step_c, sizeof(float));
    cudaMalloc((void**)&numberThreads_c, sizeof(int));

    cudaMemcpy(width_c, &width, sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(max_c, &max, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(numberThreads_c, &numberThreads, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(step_c, &step, sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(approximations_c, approximations, sizeof(int) * (size + 1) * (size + 1), cudaMemcpyHostToDevice);

    int blocks = numberThreads / blocksize + 1;
    Func << < blocks, blocksize >> > (approximations_c, step_c, max_c, width_c, numberThreads_c, size, most_of_rectangles_size_ratio);

    ms += GetCounter();

    cudaMemcpy(approximations, approximations_c, sizeof(int) * (size + 1) * (size + 1), cudaMemcpyDeviceToHost);
    

    //for (int i = 0; i < (size); i++) {
    //    for (int j = 0; j < size; j++) {
    //        cout << setw(2) << approximations[i * size + j];
    //    }
    //    cout << endl;
    //}

    cout << "\r\n\r\n" << ms << "ms" << "\r\n";

    std::fstream file("mandelbrot.pgm", std::fstream::out);
    file << "P2\n" << size << " " << size << "\n" << max-1 << "\n";
    std::string line, value;

    line = "";
    for (int i = 0; i < size * size; i++)
    {
        value = to_string(approximations[(int)(i)]);
        if (line.length() + value.length() > 69)
        {
            file << line << "\n";
            line = "";
        }
        line += value + " ";
    }

    file << line;

    file.close();


    free(approximations);
    cudaFree(approximations_c);
    cudaFree(width_c);
    cudaFree(max_c);
    cudaFree(step_c);
    cudaFree(numberThreads_c);

    return 0;
}


