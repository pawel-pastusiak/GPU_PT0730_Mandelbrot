// CPU_Mandelbrot.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>

using namespace std;

void pointApproximation(float* realPart, float* imagPart, int* maxIter, int* approximation);
void traverse(float* startX, float* startY, float* endX, float* endY, float* step, int* maxIter, int* approximation);

int main()
{
    cout << "Mandelbrot CPU" << "\r\n";

    float realPoint = 0.2;
    float imagPoint = 0.2;

    int max = 100;
    float step = 0;
    int appro = 0;

    cout << "Podaj maksymalna ilosc iteracji: ";
    cin >> max;

    cout << "Podaj dokladnosc liczby zmiennoprzecinkowej: ";
    cin >> step;

    cout << "TODO: podpiecie funkcji" << "\r\n";

    cout << "DEBUG:" << "\r\n";
    pointApproximation(&realPoint, &imagPoint, &max, &appro);
    //cout << appro;
    traverse(&realPoint, &imagPoint, new float(1.0), new float(1.0), &step, &max, &appro);
    cout << appro;

    return 0;
}

void pointApproximation(float* realPart, float* imagPart, int* maxIter, int* approximation)
{
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

void traverse(float* startX, float* startY, float* endX, float* endY, float* step, int* maxIter, int* approximation)
{
    int i = 0;
    float curX, curY;
    curX = *startX;
    while (curX < *endX) {
        curY = *startY;
        while (curY < *endY) {
            pointApproximation(&curX, &curY, maxIter, approximation);
            //cout << endl << i++ << ": " << curX << " x " << curY << ": " << *approximation;
            curY += *step;
        }
        curX += *step;
    }
}
