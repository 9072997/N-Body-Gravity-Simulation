/*  
	N-Body Gravity Simulation
	Copyright (C) 2014 Jon Penn

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <stdio.h>
const int kbodyCount = 1;
const int ktickCount = 1024*1024*1024;

int signAtBit(unsigned int bits, int position) {
	return -((bits&(1<<position))>>position)*2+1;
}

__global__ void gravify(float *bodyMass, float *bodyXposIn,  float *bodyYposIn,  float *bodyXvel,  float *bodyYvel,
										 float *bodyXposOut, float *bodyYposOut, int bodyCount) {
	int numBody;
	numBody = blockIdx.x*blockDim.x + threadIdx.x;
	//if(numBody >= bodyCount) return; // in case we have left over threads
	for(int numInfl = 0; numInfl < bodyCount; numInfl++) {
		float scale, dx, dy;
		if(bodyXposIn[numInfl]==bodyXposIn[numBody] && bodyYposIn[numInfl]==bodyYposIn[numBody]) continue; // 2 points at the same position (or we measure ourself)
		dx = bodyXposIn[numInfl] - bodyXposIn[numBody];
		dy = bodyYposIn[numInfl] - bodyYposIn[numBody];
		scale = bodyMass[numInfl] * pow(pow(dx,2) + pow(dy,2), -3/2); // initialy multiply body mass by g
		bodyXvel[numBody] += scale * dx;
		bodyYvel[numBody] += scale * dy;
	}
	bodyXposOut[numBody] = bodyXposIn[numBody] + bodyXvel[numBody];;
	bodyYposOut[numBody] = bodyYposIn[numBody] + bodyYvel[numBody];
}

int main() {
	FILE *file;
	float *bodyMass,    *bodyXpos,    *bodyYpos,   *bodyXvel,   *bodyYvel;
	float *d_bodyMass, **d_bodyXpos, **d_bodyYpos, *d_bodyXvel, *d_bodyYvel;
	
	bodyMass = (float *)malloc(kbodyCount*1024*sizeof(float));
	bodyXpos = (float *)malloc(kbodyCount*1024*sizeof(float));
	bodyYpos = (float *)malloc(kbodyCount*1024*sizeof(float));
	bodyXvel = (float *)malloc(kbodyCount*1024*sizeof(float));
	bodyYvel = (float *)malloc(kbodyCount*1024*sizeof(float));
	
	d_bodyXpos = (float **)malloc(2*sizeof(float *));
	d_bodyYpos = (float **)malloc(2*sizeof(float *));
	
	cudaMalloc(&d_bodyMass,    kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyXpos[0], kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyXpos[1], kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyYpos[0], kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyYpos[1], kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyXvel,    kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMalloc(&d_bodyYvel,    kbodyCount*1024*sizeof(float)) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	
	for(int numBody = 0; numBody < kbodyCount*1024/16; numBody++) { // each iliteration creates 16 bodys
		float mass, xpos, ypos, xvel, yvel;
		mass = abs((numBody+8156897)*49459879%500+1);
		xpos =     (numBody+5867952)*89526249%654654;
		ypos =     (numBody+7352405)*68724646%687984;
		xvel =     (numBody+8987354)*25897895%795;
		yvel =     (numBody+9444555)*16871232%826;
		
		for(int bits = 0; bits < 16; bits++) { // 16 bodys
			bodyMass[numBody*16+bits] = mass;
			bodyXpos[numBody*16+bits] = signAtBit(bits,0)*xpos;
			bodyYpos[numBody*16+bits] = signAtBit(bits,1)*ypos;
			bodyXvel[numBody*16+bits] = signAtBit(bits,2)*xvel;
			bodyYvel[numBody*16+bits] = signAtBit(bits,3)*yvel;
		}
	}
	
	file = fopen("masses.csv", "w");
	for(int numBody = 0; numBody < kbodyCount*1024; numBody++) {
		fprintf(file, "%f\n", bodyMass[numBody]);
	}
	fclose(file);
	
	cudaMemcpy(d_bodyMass,    bodyMass, kbodyCount*1024*sizeof(float), cudaMemcpyHostToDevice) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMemcpy(d_bodyXpos[0], bodyXpos, kbodyCount*1024*sizeof(float), cudaMemcpyHostToDevice) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMemcpy(d_bodyYpos[0], bodyYpos, kbodyCount*1024*sizeof(float), cudaMemcpyHostToDevice) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMemcpy(d_bodyXvel,    bodyXvel, kbodyCount*1024*sizeof(float), cudaMemcpyHostToDevice) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	cudaMemcpy(d_bodyYvel,    bodyYvel, kbodyCount*1024*sizeof(float), cudaMemcpyHostToDevice) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
	
	
	for(int numKtick = 0; numKtick < ktickCount; numKtick++) {
		char filename[60]; // 20 should be ok, but why not
		fprintf(stderr, "ktick: %d\n", numKtick);
		for(int numTick = 0; numTick < 512; numTick++) { // each loop is accuialy 2 ticks
			gravify<<< kbodyCount, 1024 >>>(d_bodyMass, d_bodyXpos[0], d_bodyYpos[0], d_bodyXvel, d_bodyYvel,
													   d_bodyXpos[1], d_bodyYpos[1], kbodyCount*1024);								
			// reverse, reverse!
			gravify<<< kbodyCount, 1024 >>>(d_bodyMass, d_bodyXpos[1], d_bodyYpos[1], d_bodyXvel, d_bodyYvel,
													   d_bodyXpos[0], d_bodyYpos[0], kbodyCount*1024);
		}
		// note here we assume we have made an even number of ilitrations
		//cudaMemcpy(bodyMass, d_bodyMass,  kbodyCount*1024*sizeof(float), cudaMemcpyDeviceToHost);
		cudaMemcpy(bodyXpos, d_bodyXpos[0], kbodyCount*1024*sizeof(float), cudaMemcpyDeviceToHost) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
		cudaMemcpy(bodyYpos, d_bodyYpos[0], kbodyCount*1024*sizeof(float), cudaMemcpyDeviceToHost) ==cudaSuccess||printf("(FAIL 1 : %s)", cudaGetErrorString(cudaGetLastError()));
		//cudaMemcpy(bodyXvel, d_bodyXvel,  kbodyCount*1024*sizeof(float), cudaMemcpyDeviceToHost);
		//cudaMemcpy(bodyYvel, d_bodyYvel,  kbodyCount*1024*sizeof(float), cudaMemcpyDeviceToHost);
		
		sprintf(filename, "ktick%010d.csv", numKtick);
		file = fopen(filename, "w");
		for(int numBody = 0; numBody < kbodyCount*1024; numBody++) {
			fprintf(file, "%f\t%f\n", bodyXpos[numBody], bodyYpos[numBody]);
		}
		fclose(file);
	}
	
	free(bodyMass);
	free(bodyXpos);
	free(bodyYpos);
	free(bodyXvel);
	free(bodyYvel);
	
	cudaFree(d_bodyMass);
	cudaFree(d_bodyXpos[0]);
	cudaFree(d_bodyXpos[1]);
	cudaFree(d_bodyYpos[1]);
	cudaFree(d_bodyYpos[0]);
	cudaFree(d_bodyXvel);
	cudaFree(d_bodyYvel);
	
	free(d_bodyXpos);
	free(d_bodyYpos);
	
	return 0;
}
