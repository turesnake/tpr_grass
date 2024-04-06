/* 
    绘制 花朵
*/
Shader "FT Scene/Flower"
{
    Properties
    {
        _ShapeTex("花形状", 2D) = "white" {}
        _Color_A("Color A", Color) = (1,1,1,1)
        _Color_B("Color B", Color) = (1,1,1,1)

        _FlowerSize ("花朵的基础尺寸", Float) = 1
        _InnSize("花内芯尺寸", Float) = 0.1
    
        //---
        [HideInInspector]_PivotPosWS("_PivotPosWS", Vector) = (0,0,0,0)
        [HideInInspector]_BoundSize("_BoundSize", Vector) = (1,1,0)
        [HideInInspector]_GroundRadiusWS ("Ground Radius", Float) = 50 // 草地半径; //超出此半径的草全被剔除;
    }



    SubShader
    {
        Tags { 
            "Queue"="AlphaTest"
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        Pass
        {
            Name "Flower" 

            Cull Back
            ZTest Less
            ZWrite On

            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

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

            #include "../Shaders/wind.hlsl"
            #include "Grass.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv           : TEXCOORD1;
                float4 rootPosWS   : TEXCOORD2;    // xyz:rootPosWS;  w:posOS.y [0,1]
                //float4 shadowCoord  : TEXCOORD3;
                float3 normalWS     : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
                float3 _PivotPosWS; // 草地 gameobj 的 posWS
                float2 _BoundSize;  // 草地 gameobj 的 localScale {x,z}
                //---
                float4 _ShapeTex_ST;
                //---
                float _FlowerSize;
                float _InnSize;
                //---
                float3 _Color_A;
                float3 _Color_B;
                //---
                float4 _WindParams;

                float _GroundRadiusWS; // 草地半径; 和 posws 同坐标比例; 超出此半径的草全被剔除;

                StructuredBuffer<float4> _AllInstancesRootPosWSBuffer;
                StructuredBuffer<float4> _AllInstancesDirWSBuffer;
            CBUFFER_END

            //-----------
            sampler2D _ShapeTex;


            // 一个草叶子( 4个三角形构成的菱形) 上的一个顶点:
            // 一个草叶子的每个顶点在调用本函数时, 它们的 instanceID 都是相同的
            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT = (Varyings)0;

                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUse_Wind = 1;           // 是否启用 风

                // ====================================================
                float3 rootPosWS = _AllInstancesRootPosWSBuffer[instanceID].xyz;
                float  stemLen   = _AllInstancesRootPosWSBuffer[instanceID].w;
                float3 dirWS        = _AllInstancesDirWSBuffer[instanceID].xyz;
                float  localScale   = _AllInstancesDirWSBuffer[instanceID].w;
                float wheatWaveDegree = _WindParams.x;
                float wheatWaveSpeed = _WindParams.y;
                float windPower = _WindParams.z;

                float grassNoise = hash12(rootPosWS.xz); // [0,1]
                grassNoise = grassNoise * 2 - 1; // [-1,1]

                //-- 基于高度信息的三种 曲线分布
                float y1 = IN.positionOS.y;
            
                //=========================================
                // UNITY_MATRIX_V == Camera.worldToCameraMatrix; 
                // 从中取出 camera 的 三个轴方向:
                float3 cameraRightWS    = UNITY_MATRIX_V[0].xyz;    //UNITY_MATRIX_V[0].xyz == world space camera Right Dir
                float3 cameraUpWS       = UNITY_MATRIX_V[1].xyz;    //UNITY_MATRIX_V[1].xyz == world space camera Up Dir
                float3 cameraForwardWS  = -UNITY_MATRIX_V[2].xyz;   //UNITY_MATRIX_V[2].xyz == world space camera Forward Dir * -1  (因为 view-space 为右手坐标系,是反的)
                //---
                
                // --- right:
                float3 rightWS = cameraRightWS;
                // --- up:
                float3 upWS = dirWS; // 花杆朝向直接读取 c# 传进来的; (也就是玩家指定的角度)
               
                // ----------------------------------------------
                float3 midPosWS = rootPosWS + dirWS * stemLen; // 花朵中心点的 posWS

                // =========== 风 =============
                if(isUse_Wind > 0.0)
                {
                    float2 pp = (rootPosWS.xz/_GroundRadiusWS) * 0.5 + 0.5;

                    float wind = calc_wind( pp, grassNoise ); // [-1,1]
                    wind = remap( -1, 1, -0.08, 0.25, wind ); // 微风, 微微向画面右侧摆动, 允许向左回弹;
                
                    float windWeight = grassNoise;
                    windWeight = saturate( pow(abs(windWeight), 2) );
                    windWeight = remap( 0, 1, 0.1, 1, windWeight );

                    wind = wind * windWeight * global_wind_weight() * windPower;
                    
                    //这里使用了个方法, 以让风只影响 三角形的 上顶点;
                    //wind *= y3; // 让草变得柔软 
                    float3 windDir = GetWindDir( wheatWaveDegree-90, wheatWaveSpeed ); // 风吹方向与 麦浪方向相同
                    float3 windOffset = windDir * wind;
                    midPosWS.xyz += windOffset;
                }

                float3 posWS = midPosWS + IN.positionOS.xyz * localScale * _FlowerSize; // !! 简陋的计算, 没有把花杆朝向算进去, 现在花始终朝向 up方向, 未来就机会再加;

                // ========
                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.rootPosWS.xyz = rootPosWS;
                OUT.rootPosWS.w = y1;
                OUT.uv = IN.uv;
                //OUT.shadowCoord = TransformWorldToShadowCoord(rootPosWS);
                OUT.normalWS = float3( 0,0, -1 );
                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                // --------------------
                float time = _Time.y % 1000; // 约束精度;
                float2 uv = IN.uv; // 手写在叶子顶点内的 uv值;
                float2 midUV = uv - 0.5;
                float3 rootPosWS = IN.rootPosWS.xyz; 

                // ----------------------------
                // 花的形状:
                float mask = tex2Dlod(_ShapeTex, float4(TRANSFORM_TEX(uv,_ShapeTex),0,0)).a;
                clip( mask - 0.5 );

                float dis = length(midUV);
                float3 baseColor = _Color_A;

                baseColor = lerp( _Color_A, _Color_B, smoothstep( _InnSize, _InnSize+0.05, dis ) );

                return half4( baseColor, 1 );
                return half4( 0, 1, 0, 1);
            }

            ENDHLSL
        }
    }
}
