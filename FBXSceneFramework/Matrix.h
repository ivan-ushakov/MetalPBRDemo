//
//  Matrix.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 16/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#pragma once

#include <fbxsdk.h>

namespace fbx
{
    FbxAMatrix MatrixMakeZero();
    
    void MatrixAddToDiagonal(FbxAMatrix &, double);
    
    void MatrixScale(FbxAMatrix &, double);
    
    // Sum two matrices element by element.
    void MatrixAdd(FbxAMatrix &, FbxAMatrix &);
}
