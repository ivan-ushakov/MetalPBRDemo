//
//  Matrix.cpp
//  FBXSceneFramework
//
//  Created by  Ivan Ushakov on 18/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#include "Matrix.h"

namespace fbx
{
    FbxAMatrix MatrixMakeZero() {
        FbxAMatrix matrix;
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                matrix[i][j] = 0.0;
            }
        }
        return matrix;
    }
    
    void MatrixAddToDiagonal(FbxAMatrix &matrix, double value) {
        matrix[0][0] += value;
        matrix[1][1] += value;
        matrix[2][2] += value;
        matrix[3][3] += value;
    }
    
    void MatrixScale(FbxAMatrix &matrix, double value) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                matrix[i][j] *= value;
            }
        }
    }
    
    // Sum two matrices element by element.
    void MatrixAdd(FbxAMatrix &dstMatrix, FbxAMatrix &srcMatrix) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dstMatrix[i][j] += srcMatrix[i][j];
            }
        }
    }
}
