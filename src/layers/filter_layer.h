//Tencent is pleased to support the open source community by making FeatherCNN available.

//Copyright (C) 2019 THL A29 Limited, a Tencent company. All rights reserved.

//Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
//in compliance with the License. You may obtain a copy of the License at
//
//https://opensource.org/licenses/BSD-3-Clause
//
//Unless required by applicable law or agreed to in writing, software distributed
//under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//CONDITIONS OF ANY KIND, either express or implied. See the License for the
//specific language governing permissions and limitations under the License.

#pragma once

#include "../feather_generated.h"
#include "../layer.h"

namespace feather
{
class FilterLayer : public Layer<float>
{
    public:
        FilterLayer(const LayerParameter* layer_param, RuntimeParameter<float>* rt_param)
            : num_output(0),
              Layer<float>(layer_param, rt_param)
        {
            num_output = layer_param->filter_param()->num_output();
        }

        int GenerateTopBlobs();
        int Forward();
        int ForwardReshape();
        int Init();

    private:
        int    num_output;
        float* select_weights;
};
};
