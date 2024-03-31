Shader "FT Scene/Grass"
{
    Properties
    {
        
        _GroundColorTex("Ground Color Tex", 2D) = "white" {}
        _NoiseColorTex("Noise Color Tex", 2D) = "white" {}

        _GroundHeightTex("Ground Height Tex", 2D) = "white" {}

        _UpColor("Up Color", Color) = (1,1,1,1)

        [Header(Grass Shape)]
        _GrassWidth("_GrassWidth", Float) = 1
        _GrassHeight("_GrassHeight", Float) = 3.5 // 草的高度


        [HideInInspector]_PivotPosWS("_PivotPosWS", Vector) = (0,0,0,0)
        [HideInInspector]_BoundSize("_BoundSize", Vector) = (1,1,0)

        [HideInInspector]_GroundRadiusWS ("Ground Radius", Float) = 50 // 草地半径; //超出此半径的草全被剔除;
    }



    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}

        Pass
        {
            Name "Grass" 

            Cull Back
            ZTest Less
            ZWrite On
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            //#pragma multi_compile _ _SHADOWS_SOFT

            // -------------------------------------
            // Unity defined keywords
            //#pragma multi_compile_fog
            // -------------------------------------

            // 必须支持 SV_InstanceID input system value
            #pragma require instancing


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //#include "gradientNoise3D.hlsl"
            #include "wind.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                
                half3 color        : COLOR;
                float2 uv           : TEXCOORD1;
                float3 rootPosWS   : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)

                float3 _PivotPosWS; // 草地 gameobj 的 posWS
                float2 _BoundSize;  // 草地 gameobj 的 localScale {x,z}

                float _GrassWidth;  // 草 宽度缩放
                float _GrassHeight; // 草 高度缩放
               
                float4 _GroundColorTex_ST;
                float4 _GroundHeightTex_ST;
                float4 _NoiseColorTex_ST;

                float3 _UpColor;

                

                float _GroundRadiusWS; // 草地半径; 和 posws 同坐标比例; 超出此半径的草全被剔除;

                // 所有草的 posWS, 按照 cell 的次序排序
                StructuredBuffer<float3> _AllInstancesTransformBuffer; // 有 11mb 大;

                // 本帧可见的 每个草叶子 的 idx 值; (在 _AllInstancesTransformBuffer 内的 idx 值)
                StructuredBuffer<uint> _VisibleInstanceOnlyTransformIDBuffer;

            CBUFFER_END



            // 绘制 物体在草地上的运动轨迹, 从而支持草地起伏效果
            sampler2D _GroundColorTex;
            sampler2D _GroundHeightTex;
            sampler2D _NoiseColorTex;


            
            // ret: [0,1]
            // float hash12(float2 p)
            // {
            //     float3 p3  = frac(float3(p.xyx) * .1031);
            //     p3 += dot(p3, p3.yzx + 33.33);
            //     return frac((p3.x + p3.y) * p3.z); // [0,1]
            // }


            // random01_: 区间[0.0,1.0]
            float3 Rotate( float3 localPosWS, float random01_ ) 
            {
                float th = remap( -1, -45, 45, 1, random01_ );
                //float th = 45;  // 逆时针 45 度;
                float2x2 mtx = float2x2(
                    cos(th), -sin(th),
                    sin(th),  cos(th)
                );
                float2 ret = mul( mtx, float2( localPosWS.x, localPosWS.z ) );
                return float3( ret.x, localPosWS.y, ret.y );
            }





            // param: wind_: 原始风力
            // param: vertexY_: 顶点在草模型内的高度, 区间:[0.0,1.0]
            float WindMagnitude( float wind_, float vertexY_ ) 
            {
                float y = vertexY_;
                float y2 = vertexY_*vertexY_; // 二阶曲线
                //y = lerp(  );




                return 0;
            }



            // 一个草叶子( 4个三角形构成的菱形) 上的一个顶点:
            // 一个草叶子的每个顶点在调用本函数时, 它们的 instanceID 都是相同的
            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT = (Varyings)0;

                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUseWind = 1;






                // ====================================================

                // 本颗草 的 root posWS; (就是草最下方的那个点)
                float3 grassRootPosWS = _AllInstancesTransformBuffer[_VisibleInstanceOnlyTransformIDBuffer[instanceID]];

                float3 viewWS = _WorldSpaceCameraPos - grassRootPosWS;// 草->camera
                float ViewWSLength = length(viewWS); // 草 到 相机距离

                float grassNoise = hash12(grassRootPosWS.xz); // [0,1]
                grassNoise = grassNoise * 2 - 1; // [-1,1]
            
                //=========================================
                // UNITY_MATRIX_V == Camera.worldToCameraMatrix; 
                // 从中取出 camera 的 三个轴方向:
                float3 cameraRightWS    = UNITY_MATRIX_V[0].xyz;    //UNITY_MATRIX_V[0].xyz == world space camera Right Dir
                float3 cameraUpWS       = UNITY_MATRIX_V[1].xyz;    //UNITY_MATRIX_V[1].xyz == world space camera Up Dir
                float3 cameraForwardWS  = -UNITY_MATRIX_V[2].xyz;   //UNITY_MATRIX_V[2].xyz == world space camera Forward Dir * -1  (因为 view-space 为右手坐标系,是反的)
                //---
                float3 upWS = lerp( cameraUpWS, float3(0,1,0), 0.6 ); // cameraUp 和 纯Up 的插值, 一个尽可能朝向天空的方向;


                // ------------ 计算 localPosWS: (在 World-Space 中, 从 grassRoot 到 本顶点 的距离偏移) -------------------
                // IN.positionOS 是本顶点在 Object-Space 里的 local pos; 
                // 我们希望这片草尽可能面向 相机, 所以要用到 WS 的相机三轴方向;
                // (一个轴一个轴地来算: 先算 相机 right 轴)
                float3 localPosWS = IN.positionOS.x * cameraRightWS * _GrassWidth * 
                                    (sin(grassRootPosWS.x*95.4643 + grassRootPosWS.z) * 0.45 + 0.55); // 让每颗草的宽度在 [0.1,1] 之间随机; (-这部分具体怎么计算无所谓-)
                
                // (相机 up 轴)
                localPosWS += IN.positionOS.y * upWS * _GrassHeight;
                //=========================================
             
                // 让那些远离 camera 的三角形变得更胖些, 以此来遮挡远处的 小于一个像素的三角形 带来的 闪烁问题;
                localPosWS += IN.positionOS.x * cameraRightWS * max(0, ViewWSLength * 0.015); // (-这部分具体怎么计算无所谓-)


                //localPosWS = Rotate( localPosWS, grassNoise );


                // ------- 计算 本顶点的真正的 posWS: --------
                float3 posWS = grassRootPosWS + localPosWS;

                // 到现在为止, 不管是 posOS 还是 posWS, 都是正面朝向 camera 的;

                




                // =========== 风 =============
                if(isUseWind > 0.0)
                {
                    float2 pp = (grassRootPosWS.xz/_GroundRadiusWS) * 0.5 + 0.5;

                    float wind = calc_wind( pp, grassNoise ); // [-1,1]
                    wind = remap( -1, 1, -0.08, 0.25, wind ); // 微风, 微微向画面右侧摆动, 允许向左回弹;
                

                    float windWeight = grassNoise;
                    windWeight = saturate( pow(abs(windWeight), 2) );
                    windWeight = remap( 0, 1, 0.1, 1, windWeight );

                    wind = wind * windWeight * global_wind_weight();

                    
                    //这里使用了个方法, 以让风只影响 三角形的 上顶点;
                    wind *= IN.positionOS.y; 
                    float3 windOffset = cameraRightWS * wind; //swing using billboard left right direction
                    posWS.xyz += windOffset;
                }


                // -------- 提前采样两个颜色 --------:
                float3 baseColor = tex2Dlod(_GroundColorTex, float4(TRANSFORM_TEX(posWS.xz,_GroundColorTex),0,0)).rgb;//sample mip 0 only
                float3 noiseColor = tex2Dlod(_NoiseColorTex, float4(TRANSFORM_TEX(posWS.xz,_NoiseColorTex),0,0)).rgb;//sample mip 0 only

                float noiseColorGray = saturate( dot(noiseColor.rgb, float3(0.299, 0.587, 0.114)) ); // 明度值;

                float heightWeight = lerp( 0.8, 1.5, noiseColorGray ); // 越亮的草越高
                heightWeight *= lerp( 1, 1.5, noiseColor.r ); // 越红的草更高
                posWS.y *= heightWeight;
                

                // 将草地约束为一个 圆形;
                float groundRaiusWS = max( abs(_GroundRadiusWS), 0.1 );
                float distancePct = saturate( length(posWS.xz) / groundRaiusWS );
                float distancePct2 = distancePct * distancePct;
                float distancePct3 = lerp( distancePct2, distancePct, distancePct ); // 边缘比 2版 更暗;


                // ============================ color ===========================        
                float3 upColor = lerp( _UpColor, noiseColor, 0.8 );
                upColor = lerp( baseColor, upColor, 0.5 * (1-distancePct3) );
              
                

                // 简单补充: 草从下往上渐变色;
                float3 lightingResult = lerp( baseColor, upColor, IN.positionOS.y * IN.positionOS.y );


                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.color = lightingResult;
                OUT.rootPosWS = grassRootPosWS;

                OUT.uv = IN.uv;

                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                // float2 uv = IN.uv; // 手写在叶子顶点内的 uv值;

                // float groundSize = 2.0;
                // float2 groundUV = frac( IN.rootPosWS.xz / groundSize );


                // float height = tex2Dlod(_GroundHeightTex, float4(TRANSFORM_TEX(groundUV,_GroundHeightTex),0,0)).r;//sample mip 0 only


                // return half4( height, height, height, 1); 

                // //return half4( groundUV.x, groundUV.y, 0,1);

                return half4(IN.color,1);
            }



            ENDHLSL
        }
    }
}