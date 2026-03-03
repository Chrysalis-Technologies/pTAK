#include <cuda_runtime.h>
#include <cstdio>
#include <cmath>
#include <cstdlib>

__global__ void burn(float* out, int n, int iters) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    float x = (float)(idx % 2048) * 0.001f + 1.0f;
    #pragma unroll 4
    for (int i = 0; i < iters; ++i) {
        x = sqrtf(fabsf(x)) + sinf(x) * cosf(x) + 0.000001f;
    }
    out[idx] = x;
}

int main(int argc, char** argv) {
    int launches = 64;
    if (argc > 1) launches = atoi(argv[1]);

    const int n = 1 << 24;
    const int threads = 256;
    const int blocks = (n + threads - 1) / threads;

    float* d = nullptr;
    cudaError_t err = cudaMalloc(&d, n * sizeof(float));
    if (err != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed: %s\n", cudaGetErrorString(err));
        return 1;
    }

    printf("Running CUDA burn: launches=%d\n", launches);
    fflush(stdout);

    for (int i = 0; i < launches; ++i) {
        burn<<<blocks, threads>>>(d, n, 1024);
        err = cudaGetLastError();
        if (err != cudaSuccess) {
            fprintf(stderr, "Kernel launch failed at %d: %s\n", i, cudaGetErrorString(err));
            cudaFree(d);
            return 2;
        }
    }

    err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        fprintf(stderr, "cudaDeviceSynchronize failed: %s\n", cudaGetErrorString(err));
        cudaFree(d);
        return 3;
    }

    printf("Done.\n");
    cudaFree(d);
    return 0;
}
