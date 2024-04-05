/* 
    easy color:
*/
Shader "FT Scene/Grass3"
{
    Properties
    {
        _GroundHeightTex("叶子高度波动", 2D) = "white" {}
        _WheatTex("麦浪", 2D) = "white" {}
        _DirNormalTex("叶子倒伏", 2D) = "white" {}


        _ShadowColor("Shadow Color", Color) = (1,1,1,1)
        _DownColor("Down Color", Color) = (1,1,1,1)
        _UpColor("Up Color", Color) = (1,1,1,1)
        

        _HighLightColor("hight light Color", Color) = (1,1,1,1)


       
        [Header(Grass Shape)]
        _Grass("x:叶宽; y:叶高;", Vector) = ( 0.05, 0.7, 0, 0 )
        _GrassHeightRange("叶高波动区间(百分比); x:min; y:max", Vector) = ( 0.6, 1.3, 0, 0 )
        _GridSizes("网格(正方形)边长: x:地面网格, y:麦浪网格", Vector) = (11, 15, 0, 0)

    
        _wheatWaveDegree("麦浪方向夹角(0,360)", Range(0,360)) = 0
        _Wind("x:麦浪运动速度(可正负); y:风力大小;", Vector) = ( 1.5, 2, 0, 0 )

        //---
        [HideInInspector]_PivotPosWS("_PivotPosWS", Vector) = (0,0,0,0)
        [HideInInspector]_BoundSize("_BoundSize", Vector) = (1,1,0)
        [HideInInspector]_GroundRadiusWS ("Ground Radius", Float) = 50 // 草地半径; //超出此半径的草全被剔除;
    }



    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}

        Pass
        {
            Name "Grass3" 

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

            //#include "gradientNoise3D.hlsl"
            #include "../Shaders/wind.hlsl"
            #include "Grass2.hlsl"


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
                float4 shadowCoord  : TEXCOORD3;
                float3 viewWS       : TEXCOORD4;
                float3 normalWS     : TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
                float3 _PivotPosWS; // 草地 gameobj 的 posWS
                float2 _BoundSize;  // 草地 gameobj 的 localScale {x,z}
                //---
                float4 _GroundHeightTex_ST;
                float4 _WheatTex_ST;
                float4 _DirNormalTex_ST;
                //---
                float4 _Grass;
                float4 _GrassHeightRange;
                float4 _GridSizes;

                
                //---
                float3 _ShadowColor;
                float3 _DownColor;
                float3 _UpColor;
                float3 _HighLightColor;
                //---
                float _wheatWaveDegree;
                float4 _Wind;

                float _GroundRadiusWS; // 草地半径; 和 posws 同坐标比例; 超出此半径的草全被剔除;

                // 所有草的 posWS, 按照 cell 的次序排序
                StructuredBuffer<float3> _AllInstancesTransformBuffer; // 有 11mb 大;

                // 本帧可见的 每个草叶子 的 idx 值; (在 _AllInstancesTransformBuffer 内的 idx 值)
                StructuredBuffer<uint> _VisibleInstanceOnlyTransformIDBuffer;

            CBUFFER_END

            //-----------
            sampler2D _GroundHeightTex;
            sampler2D _WheatTex;
            sampler2D _DirNormalTex;
            
    

            // 一个草叶子( 4个三角形构成的菱形) 上的一个顶点:
            // 一个草叶子的每个顶点在调用本函数时, 它们的 instanceID 都是相同的
            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT = (Varyings)0;

                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUse_Wind = 1;           // 是否启用 风
                float isUse_GroundHeight = 1;   // 是否使用  _GroundHeightTex 里的数据来制作 整块起伏的 草地样貌
                float isFarGrassFatter = 1;    // 是否让远处的叶片变得更宽
                float isSetGrassDir = 1;


                // ====================================================

                // 本颗草 的 root posWS; (就是草最下方的那个点)
                float3 grassRootPosWS = _AllInstancesTransformBuffer[_VisibleInstanceOnlyTransformIDBuffer[instanceID]];

                float groundGridSize = _GridSizes.x;
                float2 groundUV = frac( grassRootPosWS.xz / groundGridSize );

                float3 viewWS = _WorldSpaceCameraPos - grassRootPosWS;// 草->camera
                float ViewWSLength = length(viewWS); // 草 到 相机距离

                float grassNoise = hash12(grassRootPosWS.xz); // [0,1]
                grassNoise = grassNoise * 2 - 1; // [-1,1]


                //-- 基于高度信息的三种 曲线分布
                float y1 = IN.positionOS.y;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;

            
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
                //float3 upWS = normalize( lerp( cameraUpWS, float3(0,1,0), 0.8 )); // cameraUp 和 纯Up 的插值, 一个尽可能朝向天空的方向;
                float3 upWS = float3(0,1,0);

                // --- grassWidth: 
                float grassWidth = _Grass.x;
                grassWidth = grassWidth * remap( -1,1, 0.3, 1, sin(grassRootPosWS.x*95.4643 + grassRootPosWS.z)); // 让每颗草的宽度在 [0.1,1] 之间随机; (-这部分具体怎么计算无所谓-)

                if( isFarGrassFatter > 0 )
                {
                    // 让那些远离 camera 的三角形变得更胖些, 以此来遮挡远处的 小于一个像素的三角形 带来的 闪烁问题;
                    grassWidth += max(0, ViewWSLength * 0.015); // (-这部分具体怎么计算无所谓-)
                }

                // --- grassHeight:
                float grassHeight = _Grass.y;

                if(isUse_GroundHeight > 0)
                {
                    float height1 = tex2Dlod(_GroundHeightTex, float4(TRANSFORM_TEX(groundUV,_GroundHeightTex),0,0)).r;//sample mip 0 only
                    grassHeight *= remap( 0, 1, _GrassHeightRange.x, _GrassHeightRange.y, height1 );
                }


                if( isSetGrassDir > 0 ) 
                {
                    float3x3 tangentTransform = float3x3(
                        float3(1,0,0), // tangent
                        float3(0,0,1), // bitangent
                        float3(0,1,0)  // normal
                    );
                    float3 normalMapVal = UnpackNormal( tex2Dlod(_DirNormalTex, float4(TRANSFORM_TEX(groundUV,_DirNormalTex),0,0)).rgba);                
                    float3 normalDirWS = SafeNormalize(mul(normalMapVal, tangentTransform));
                    
                    



                    upWS = lerp(upWS, normalDirWS, 0.6);
                }


                // ----------------------------------------------
                // --- localPosWS: (在 World-Space 中, 从 grassRoot 到 本顶点 的距离偏移):
                // (注: IN.positionOS 是本顶点在 Object-Space 里的 local pos)
                float3 localPosWS = (IN.positionOS.x * rightWS * grassWidth) + (IN.positionOS.y * upWS * grassHeight);
                // ---  本顶点的真正的 posWS:
                float3 posWS = grassRootPosWS + localPosWS;


                // =========== 风 =============
                if(isUse_Wind > 0.0)
                {
                    float2 pp = (grassRootPosWS.xz/_GroundRadiusWS) * 0.5 + 0.5;

                    float wind = calc_wind( pp, grassNoise ); // [-1,1]
                    wind = remap( -1, 1, -0.08, 0.25, wind ); // 微风, 微微向画面右侧摆动, 允许向左回弹;
                
                    float windWeight = grassNoise;
                    windWeight = saturate( pow(abs(windWeight), 2) );
                    windWeight = remap( 0, 1, 0.1, 1, windWeight );

                    wind = wind * windWeight * global_wind_weight() * _Wind.y;
                    
                    //这里使用了个方法, 以让风只影响 三角形的 上顶点;
                    wind *= y3; // 让草变得柔软 
                    float3 windDir = GetWindDir( _wheatWaveDegree-90, _Wind.x ); // 风吹方向与 麦浪方向相同
                    float3 windOffset = windDir * wind;
                    posWS.xyz += windOffset;
                }

                // ========
                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.rootPosWS.xyz = grassRootPosWS;
                OUT.rootPosWS.w = y1;
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(grassRootPosWS);
                OUT.viewWS = _WorldSpaceCameraPos - posWS;
                OUT.normalWS = float3( 0,0, -1 );
                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUseWheatWave = 1;

                // --------------------
                float time = _Time.y % 1000; // 约束精度;
                float2 uv = IN.uv; // 手写在叶子顶点内的 uv值;
                float3 rootPosWS = IN.rootPosWS.xyz; 
                float groundGridSize = _GridSizes.x;
                float wheatWaveGridSize = _GridSizes.y;
                float y1 = IN.rootPosWS.w;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;
                float y4 = y2 * y2;

                // ----------------------------
                float3 upColor = _UpColor;
                // -------------- wheat wave --------------
                if(isUseWheatWave > 0)
                {
                    float2 wheatUV = GetWheatWaveUV( rootPosWS, _wheatWaveDegree, wheatWaveGridSize, time, _Wind.x );
                    float wheatVal = tex2Dlod(_WheatTex, float4(TRANSFORM_TEX(wheatUV,_WheatTex),0,0)).r;
                    upColor = lerp( upColor, _HighLightColor, wheatVal);
                }

                //------------- shadow ---------------
                Light mainLight = GetMainLight(IN.shadowCoord);
                half shadow = mainLight.shadowAttenuation; // light:1; shadow:0
                //---
                half3 c = lerp( _DownColor, upColor, y2 ); // 叶子上下分色
                c = lerp( _ShadowColor, c, shadow ); // 给阴影处上色
                return half4(c,1);
            }

            ENDHLSL
        }
    }
}