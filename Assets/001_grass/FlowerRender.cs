//see this for ref: https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html

using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Profiling;

using UnityEngine.Rendering;




//[ExecuteAlways]
public class FlowerRender : MonoBehaviour
{
    public Transform flowersFieldRootTF; // 花场root, 在此节点内收集所有 FlowerFlag
    public Material stemMaterial; // 花杆
    public Material flowerMaterial; // 花朵

    public float stemLenScale = 1f;


    ComputeBuffer allInstancesPosWSBuffer; 
    ComputeBuffer allInstancesDirWSBuffer; 

    // 存储一些参数, 其中只有 5 个 uint 值;
    ComputeBuffer stemArgsBuffer;
    ComputeBuffer flowerArgsBuffer;

    int instanceCount;// 花的数量
    float   minX = 9999999f, 
            minZ = 9999999f, 
            maxX = -9999999f, 
            maxZ = -9999999f; // 所有花的 posws 的最值;

    List<Vector4> floweRootPosWSList = new List<Vector4>(); // xyz: posWS, w:len
    List<Vector4> flowerDirWSList = new List<Vector4>();

    bool isPosWSPrepared = false;
    bool isBuffersPrepared = false;
    float groundRadius = 0f; // 草地半径;

    static int _AllInstancesRootPosWSBuffer = Shader.PropertyToID("_AllInstancesRootPosWSBuffer"); // 塞入 floweRootPosWSList
    static int _AllInstancesDirWSBuffer = Shader.PropertyToID("_AllInstancesDirWSBuffer"); // 塞入 flowerDirWSList

    static int _GroundRadiusWS = Shader.PropertyToID("_GroundRadiusWS");


    //=====================================================
    
    void PreparePosWS()
    {
        if( isPosWSPrepared )
        {
            return;
        }
        isPosWSPrepared = true;

        Debug.Log("---- PreparePosWS() ----");

        UnityEngine.Random.InitState(155); // 用一个指定的种子来初始化 random, 从而确保在每次运行时, 地面上的草长的都是一样的;

        // 确保 草地一定是个 xz 正方形; y值无意义;
        float maxLocalScale = Mathf.Max( transform.localScale.x, transform.localScale.z );
        maxLocalScale = Mathf.Max( maxLocalScale, 1f ); // 强制设置不能太小;
        transform.localScale = new Vector3(maxLocalScale, 1f, maxLocalScale);
        groundRadius = maxLocalScale * 0.5f;
        


        var allFlowerFlags = flowersFieldRootTF.GetComponentsInChildren<FlowerFlag>(false);
        instanceCount = allFlowerFlags.Length;
        for( int i=0; i<allFlowerFlags.Length; i++ ) 
        {
            var fFlag = allFlowerFlags[i];
            var rootPos = fFlag.rootTF.position;
            var dir = (fFlag.topTF.position - fFlag.rootTF.position).normalized;
            float len = (fFlag.topTF.position - fFlag.rootTF.position).magnitude * stemLenScale;
            float localScale = fFlag.topTF.localScale.x;
            //---
            floweRootPosWSList.Add(  new Vector4( rootPos.x, rootPos.y, rootPos.z, len ) );
            flowerDirWSList.Add(       new Vector4( dir.x, dir.y, dir.z, localScale) );
            //---
            UpdateBoundsParams(rootPos);
            fFlag.gameObject.SetActive(false); // 隐藏
        }
    }


    void PrepareBuffers()
    {
        if (    isBuffersPrepared  
            &&  stemArgsBuffer != null 
            &&  flowerArgsBuffer != null 
            &&  allInstancesPosWSBuffer != null 
            &&  allInstancesDirWSBuffer != null
        ){
            return;
        }
        isBuffersPrepared = true;

        Debug.Log("---- PrepareBuffers() ----");
    
 
        // ----------------------------------
        if (allInstancesPosWSBuffer != null)
        {
            allInstancesPosWSBuffer.Release();
        }
        //  {posWS + len}, per flower  参数{ count, stride }  --- 一个元素 占用 float4
        allInstancesPosWSBuffer = new ComputeBuffer(instanceCount, sizeof(float)*4); 

        if (allInstancesDirWSBuffer != null)
        {
            allInstancesDirWSBuffer.Release();
        }
        //  {dirWS + localScale}, per flower  参数{ count, stride }  --- 一个元素 占用 float4
        allInstancesDirWSBuffer = new ComputeBuffer(instanceCount, sizeof(float)*4); 



        allInstancesPosWSBuffer.SetData(floweRootPosWSList);
        allInstancesDirWSBuffer.SetData(flowerDirWSList);

        //--
        stemMaterial.SetFloat( _GroundRadiusWS, groundRadius );
        stemMaterial.SetBuffer(_AllInstancesRootPosWSBuffer, allInstancesPosWSBuffer);
        stemMaterial.SetBuffer(_AllInstancesDirWSBuffer, allInstancesDirWSBuffer);
        //--
        flowerMaterial.SetFloat( _GroundRadiusWS, groundRadius );
        flowerMaterial.SetBuffer(_AllInstancesRootPosWSBuffer, allInstancesPosWSBuffer);
        flowerMaterial.SetBuffer(_AllInstancesDirWSBuffer, allInstancesDirWSBuffer);


        // ==========================
        if (stemArgsBuffer != null)
        {
            stemArgsBuffer.Release();
        }
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        stemArgsBuffer = new ComputeBuffer(
            1,                                  // count: 只有 1 个元素
            args.Length * sizeof(uint),         // stride: 步长, 5个uint
            ComputeBufferType.IndirectArguments // type
        );
        // 这 5 个元素的配置是必须固定的, 参见 Graphics.DrawMeshInstancedIndirect() 文档;
        args[0] = (uint)GetStemMeshCache().GetIndexCount(0);   // 顶点个数, 3 个;    (参数, submesh idx)
        args[1] = (uint)instanceCount;                      // 草的个数, 后面会被改写成 visibleInstancesOnlyPosWSIDBuffer 的元素个数
        args[2] = (uint)GetStemMeshCache().GetIndexStart(0);   // 目标 submesh 在 index buffer 中 第一个元素的 下标值;
        args[3] = (uint)GetStemMeshCache().GetBaseVertex(0);   // 有点含糊的一个概念, 此处为 0;
        args[4] = 0;                                            // start instance location. 教材和本例中都写 0... 
        stemArgsBuffer.SetData(args);


        // ==========================
        if (flowerArgsBuffer != null)
        {
            flowerArgsBuffer.Release();
        }
        flowerArgsBuffer = new ComputeBuffer(
            1,                                  // count: 只有 1 个元素
            args.Length * sizeof(uint),         // stride: 步长, 5个uint
            ComputeBufferType.IndirectArguments // type
        );
        // 这 5 个元素的配置是必须固定的, 参见 Graphics.DrawMeshInstancedIndirect() 文档;
        args[0] = (uint)GetFlowerMeshCache().GetIndexCount(0);   // 顶点个数, 3 个;    (参数, submesh idx)
        args[1] = (uint)instanceCount;                      // 草的个数, 后面会被改写成 visibleInstancesOnlyPosWSIDBuffer 的元素个数
        args[2] = (uint)GetFlowerMeshCache().GetIndexStart(0);   // 目标 submesh 在 index buffer 中 第一个元素的 下标值;
        args[3] = (uint)GetFlowerMeshCache().GetBaseVertex(0);   // 有点含糊的一个概念, 此处为 0;
        args[4] = 0;                                            // start instance location. 教材和本例中都写 0... 
        flowerArgsBuffer.SetData(args);
    }



 

    void Start()
    {
        Debug.Log("---- Start() -----");
        Debug.Assert( stemLenScale > 0.01f );
        Debug.Assert( stemMaterial && flowerMaterial );
        if( SystemInfo.supportsComputeShaders == false )
        {
            return;
        }
        PreparePosWS();
    }



    void LateUpdate()
    {
        if( SystemInfo.supportsComputeShaders == false )
        {
            return;
        }

        PrepareBuffers();

        Camera cam =Camera.main;
         
        // 一整个草地 xz正方形 的 包围盒;  
        // 若 camera frustum 和这个 bound 不相交, 那么下面的 DrawMeshInstancedIndirect() 甚至不会执行渲染;
        Bounds renderBound = new Bounds();
        renderBound.SetMinMax(
            new Vector3(minX, 0, minZ), 
            new Vector3(maxX, 0, maxZ)
        );
        
        // 绘制 花杆:
        // gpu instancing, 绘制很多个重复的 mesh; 此函数底层依赖 compute shader;
        Graphics.DrawMeshInstancedIndirect(
            GetStemMeshCache(),    // 一个 花杆 的 mesh
            0,                      // subMeshidx
            stemMaterial,               // material
            renderBound,            // bounds
            stemArgsBuffer,             // bufferWithArgs; 这个 buffer 的配置是必须固定的;
            // --- 下面是原本可以使用默认值的一些参数, 此处手动设置: ---
            0,                      // argsOffset
            null,                   // MaterialPropertyBlock
            ShadowCastingMode.Off,  //
            false,                  // receiveShadows
            0,                      // layer
            cam,                    // camera
            LightProbeUsage.Off,    // 
            null                    // lightProbeProxyVolume
        );


        // 绘制 花朵:
        Graphics.DrawMeshInstancedIndirect(
            GetFlowerMeshCache(),    // 一个草的 mesh, 三角形
            0,                      // subMeshidx
            flowerMaterial,               // material
            renderBound,            // bounds
            flowerArgsBuffer,             // bufferWithArgs; 这个 buffer 的配置是必须固定的;
            // --- 下面是原本可以使用默认值的一些参数, 此处手动设置: ---
            0,                      // argsOffset
            null,                   // MaterialPropertyBlock
            ShadowCastingMode.Off,  //
            false,                  // receiveShadows
            0,                      // layer
            cam,                    // camera
            LightProbeUsage.Off,    // 
            null                    // lightProbeProxyVolume
        );
    }



    void OnDisable()
    {
        Debug.Log("---- OnDisable() -----");

        //release all compute buffers
        if (allInstancesPosWSBuffer != null)
            allInstancesPosWSBuffer.Release();
        allInstancesPosWSBuffer = null;

        if (allInstancesDirWSBuffer != null)
            allInstancesDirWSBuffer.Release();
        allInstancesDirWSBuffer = null;

        if (stemArgsBuffer != null)
            stemArgsBuffer.Release();
        stemArgsBuffer = null;

        if (flowerArgsBuffer != null)
            flowerArgsBuffer.Release();
        flowerArgsBuffer = null;

        isBuffersPrepared = false;
    }


   
    Mesh GetStemMeshCache()
    {
        return MeshCreater.GetGrassMesh_Rect();
    }

    Mesh GetFlowerMeshCache()
    {
        return MeshCreater.GetGrassMesh_Rect2();
    }


    void UpdateBoundsParams( Vector3 posWS_ )
    {
        minX = Mathf.Min( minX, posWS_.x );
        minZ = Mathf.Min( minZ, posWS_.z );
        maxX = Mathf.Max( maxX, posWS_.x );
        maxZ = Mathf.Max( maxZ, posWS_.z );
    }







}