//see this for ref: https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html

using System;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Profiling;

using UnityEngine.Rendering;


// 建议 transform.localScale 设置为 (30,1,30)

//[ExecuteAlways]
public class GrassRender : MonoBehaviour
{

    //[Range(1, 40000000)]
    [Header("Settings")]
    public int instanceCount = 50000;// 草的数量

    // 草的最远绘制距离; 很影响性能; 也会影响 相机的 farClipPlane;
    public float drawDistance = 125;

    public Material material; // 每颗草的材质球, 既实现草的运动, 也实现草的渲染;

    public ComputeShader cullingComputeShader; // 目标 compute shader


    //=====================================================
    // cell: 一个正方形区域, 整个草地被切割成数个 cell;
    // (此值不宜太小, 它很影响 cpu, 但不怎么影响 gpu)
    const float presetCellSize = 15f; // 预设的一个 cell 的边长为多少米 (unity unit (m));  
    float cellSize = -1; // [计算中获得]: 实际上一个 cell 的边长为多少米; 此值和 presetCellSize 可能存在差异
    int cellCount = -1;  // [计算中获得]: 草地的每个轴方向(x,z) 可分割为多少个 cell;
    

    // 就是 "_AllInstancesTransformBuffer", 在 渲染 shader 中被使用;
    // 存储 所有草的 posws, 按所属的 cell 的次序排序; 
    ComputeBuffer allInstancesPosWSBuffer; 

    // 是 compute shader 的输出值: "_VisibleInstancesOnlyPosWSIDBuffer", 
    // 每帧开始时, 此 buffer 都会被清空为 0 个元素, 然后在 computer shader kernerl 内被逐个填入元素:
    // 填入 本帧可见的 每个草 的 idx 值; (在 allInstancesPosWSBuffer 内的 idx 值)
    ComputeBuffer visibleInstancesOnlyPosWSIDBuffer;

    // 存储一些参数, 其中只有 5 个 uint 值;
    ComputeBuffer argsBuffer;


    // 每个 cell 维护一个 List<Vector3>, 里面存放了 本 cell 里的所有 草的 posWS
    List<Vector3>[] cellPosWSsList; 


    float minX, minZ, maxX, maxZ; // 所有草的 posws 的最值;


    List<int> visibleCellIDList = new List<int>(); // 本帧 可见的 cells 的 id; (frustum之外的 cells 将被剔除)

    Plane[] cameraFrustumPlanes = new Plane[6];// 目标 camera 的 frustum 的 6 个平面;

    bool shouldBatchDispatch = true;

    bool isPosWSPrepared = false;
    bool isBuffersPrepared = false;


    Vector3 numthreads = new Vector3( 64f, 1f, 1f ); // 这个配置一定要和 compute shader kernel 中的 numthreads 配置一样;

    float groundRadius = 0f; // 草地半径;
    bool isSupportComputeShader = true;


    static int _PivotPosWS = Shader.PropertyToID("_PivotPosWS");
    static int _AllInstancesTransformBuffer = Shader.PropertyToID("_AllInstancesTransformBuffer");
    static int _VisibleInstanceOnlyTransformIDBuffer = Shader.PropertyToID("_VisibleInstanceOnlyTransformIDBuffer");
    static int _AllInstancesPosWSBuffer = Shader.PropertyToID("_AllInstancesPosWSBuffer");
    static int _VisibleInstancesOnlyPosWSIDBuffer = Shader.PropertyToID("_VisibleInstancesOnlyPosWSIDBuffer");
    static int _VPMatrix = Shader.PropertyToID("_VPMatrix");
    static int _MaxDrawDistance = Shader.PropertyToID("_MaxDrawDistance");
    static int _StartOffset = Shader.PropertyToID("_StartOffset");
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

        minX = transform.position.x - groundRadius;
        maxX = transform.position.x + groundRadius;
        minZ = transform.position.z - groundRadius;
        maxZ = transform.position.z + groundRadius;

        cellCount = Mathf.CeilToInt( (groundRadius * 2f) / presetCellSize);
        cellSize = groundRadius*2f / (float)cellCount;
        
        Debug.Log(" cellCount: " + cellCount );
        Debug.Log(" cellSize: " + cellSize );
        Debug.Log(" cell 的数量: " + (cellCount*cellCount) );

        
        // 每个 cell 维护一个 List<Vector3>, 里面存放了 本 cell 里的所有 元素的 posWS
        cellPosWSsList = new List<Vector3>[cellCount*cellCount];
        for (int i = 0; i < cellPosWSsList.Length; i++)
        {
            cellPosWSsList[i] = new List<Vector3>();
        }

    
        for (int i = 0; i < instanceCount; i++)// 生成每一颗草 的 posws
        {
            // --- 球形分布, 中心 0.2 区域最密集, 越往外越稀疏: 
            Vector3 posOS = UnityEngine.Random.onUnitSphere * groundRadius;
            float f = UnityEngine.Random.Range(0.5f, 1f);
            float f2 = f * f;
            float f3 = Mathf.Lerp( f2, f, f );

            float ff = UnityEngine.Random.Range(0.7f, 1f);

            posOS *= f3 * ff;
            posOS.y = 0f;

            Vector3 posWS = posOS + transform.position;

            // -----------------
            // find cellID, 区间:[0, cellCount-1]
            int xID = Mathf.Min( 
                cellCount - 1, 
                Mathf.FloorToInt( Mathf.InverseLerp(minX, maxX, posWS.x) * cellCount ) // FloorToInt(): 小于等于 f 的最大整数;
            ); 
            int zID = Mathf.Min( 
                cellCount - 1, 
                Mathf.FloorToInt( Mathf.InverseLerp(minZ, maxZ, posWS.z) * cellCount )  // FloorToInt(): 小于等于 f 的最大整数;
            );
            int cellID = xID + zID * cellCount;

            cellPosWSsList[cellID].Add(posWS);
        }
    }


    void PrepareBuffers()
    {
        if (isBuffersPrepared  &&
            argsBuffer != null &&
            allInstancesPosWSBuffer != null &&
            visibleInstancesOnlyPosWSIDBuffer != null)
        {
            return;
        }
        isBuffersPrepared = true;

        Debug.Log("---- PrepareBuffers() ----");

        
        material.SetFloat( _GroundRadiusWS, groundRadius );
        material.SetVector(_PivotPosWS, transform.position);

 
        // ----------------------------------
        if (allInstancesPosWSBuffer != null)
        {
            allInstancesPosWSBuffer.Release();
        }
        // float3 posWS only, per grass  参数{ count, stride }  --- 一个元素 占用 float3
        allInstancesPosWSBuffer = new ComputeBuffer(instanceCount, sizeof(float)*3); 

        // ----------------------------------
        if (visibleInstancesOnlyPosWSIDBuffer != null)
        {
            visibleInstancesOnlyPosWSIDBuffer.Release();
        }
        visibleInstancesOnlyPosWSIDBuffer = new ComputeBuffer( 
            instanceCount,          // count:  buffer 的元素的个数
            sizeof(uint),           // stride: 单个元素步长;
            ComputeBufferType.Append// type:   类似 stack, 可在尾部 添加和删除元素; 可关连 hlsl 中的 AppendStructuredBuffer buffer (正是我们用的类型)   
        );

        //combine to a flatten array for compute buffer
        int offset = 0;
    
        // 将 cellPosWSsList 中所有元素(草的posws) 展平, 放到一个 扁平的数组中; 
        Vector3[] allGrassPosWSSortedByCell = new Vector3[instanceCount]; // 草的个数
        for (int j = 0; j < cellPosWSsList.Length; j++) // cell 的数量
        {
            for (int i = 0; i < cellPosWSsList[j].Count; i++) // cell 中草的数量
            {
                allGrassPosWSSortedByCell[offset] = cellPosWSsList[j][i];
                offset++;
            }
        }

        allInstancesPosWSBuffer.SetData(allGrassPosWSSortedByCell);
        material.SetBuffer(_AllInstancesTransformBuffer, allInstancesPosWSBuffer);
        material.SetBuffer(_VisibleInstanceOnlyTransformIDBuffer, visibleInstancesOnlyPosWSIDBuffer);

        // ==========================
        if (argsBuffer != null)
        {
            argsBuffer.Release();
        }
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        argsBuffer = new ComputeBuffer(
            1,                                  // count: 只有 1 个元素
            args.Length * sizeof(uint),         // stride: 步长, 5个uint
            ComputeBufferType.IndirectArguments // type
        );

        // 这 5 个元素的配置是必须固定的, 参见 Graphics.DrawMeshInstancedIndirect() 文档;
        args[0] = (uint)GetGrassMeshCache().GetIndexCount(0);   // 顶点个数, 3 个;    (参数, submesh idx)
        args[1] = (uint)instanceCount;                      // 草的个数, 后面会被改写成 visibleInstancesOnlyPosWSIDBuffer 的元素个数
        args[2] = (uint)GetGrassMeshCache().GetIndexStart(0);   // 目标 submesh 在 index buffer 中 第一个元素的 下标值;
        args[3] = (uint)GetGrassMeshCache().GetBaseVertex(0);   // 有点含糊的一个概念, 此处为 0;
        args[4] = 0;                                            // start instance location. 教材和本例中都写 0... 

        argsBuffer.SetData(args);

        // ========================       
        // set buffer
        cullingComputeShader.SetFloat( _GroundRadiusWS, groundRadius );
        cullingComputeShader.SetBuffer(0, _AllInstancesPosWSBuffer, allInstancesPosWSBuffer);
        cullingComputeShader.SetBuffer(0, _VisibleInstancesOnlyPosWSIDBuffer, visibleInstancesOnlyPosWSIDBuffer);
    }

    void Awake()
    {
    }


    void OnEnable()
    {
    }



    void Start()
    {
        Debug.Log("---- Start() -----");

        isSupportComputeShader = SystemInfo.supportsComputeShaders;
        if( isSupportComputeShader == false )
        {
            return;
        }

        PreparePosWS();
    }



    void LateUpdate()
    {
        if( isSupportComputeShader == false )
        {
            return;
        }

        PrepareBuffers();

        //=====================================================================================================
        // rough quick big cell frustum culling in CPU first -- 粗略快速的 cpu 端 cell级 frustum 剔除;
        //=====================================================================================================
        visibleCellIDList.Clear();//fill in this cell ID list using CPU frustum culling first

        // 设置 buffer 的 元素个数; 暂时置0;
        // 本 buffer 是 append buffer(可在尾后添加元素); 此类 buffer 使用一个特殊的 counter 变量来跟踪 buffer 中元素的个数;
        visibleInstancesOnlyPosWSIDBuffer.SetCounterValue(0);

        //Camera cam = CameraUtil.GetDefaultMainCamera();
        Camera cam =Camera.main;

        // Do frustum culling using per cell bound
        float oldFarClipPlane = cam.farClipPlane; // 缓存
        cam.farClipPlane = drawDistance;
        GeometryUtility.CalculateFrustumPlanes(cam, cameraFrustumPlanes); //Ordering: [0] = Left, [1] = Right, [2] = Down, [3] = Up, [4] = Near, [5] = Far
        cam.farClipPlane = oldFarClipPlane; // 还原原值

        // slow loop
        Profiler.BeginSample("CPU cell frustum culling (heavy)");

        // 一个 cell 的尺寸;
        Vector3 sizeWS = new Vector3( cellSize, 0, cellSize );
        
        // 剔除掉 frustum 之外的 cells;
        for (int i = 0; i < cellPosWSsList.Length; i++)// 所有 cell
        {
            //create cell bound
            Vector3 centerPosWS = new Vector3 ( i % cellCount + 0.5f, 0, i / cellCount + 0.5f );// 每个 cell 的 center posws
            // 进一步约束到 实际分配的 随机值范围内;
            centerPosWS.x = Mathf.Lerp(minX, maxX, centerPosWS.x / cellCount);
            centerPosWS.z = Mathf.Lerp(minZ, maxZ, centerPosWS.z / cellCount);

            Bounds cellBound = new Bounds(centerPosWS, sizeWS );

            if (GeometryUtility.TestPlanesAABB(cameraFrustumPlanes, cellBound))
            {
                visibleCellIDList.Add(i);
            }
        }

        Profiler.EndSample();

        //=====================================================================================================
        // then loop though only visible cells, each visible cell dispatch GPU culling job once
        // at the end compute shader will fill all visible instance into visibleInstancesOnlyPosWSIDBuffer
        //=====================================================================================================
        
        Matrix4x4 v = cam.worldToCameraMatrix;
        Matrix4x4 p = cam.projectionMatrix;
        Matrix4x4 vp = p * v;

        //set once only
        cullingComputeShader.SetMatrix(_VPMatrix, vp);
        cullingComputeShader.SetFloat(_MaxDrawDistance, drawDistance); // 是个用户设置的 固定值;


        //dispatch per visible cell
        for (int i = 0; i < visibleCellIDList.Count; i++)// 本帧的 每个可见 cell
        {

            int targetCellFlattenID = visibleCellIDList[i];

            int memoryOffset = 0;
            for (int j = 0; j < targetCellFlattenID; j++)
            {
                memoryOffset += cellPosWSsList[j].Count;
            }

            // culling read data started at offseted pos, will start from cell's total offset in memory
            cullingComputeShader.SetInt(_StartOffset, memoryOffset); 

            int jobLength = cellPosWSsList[targetCellFlattenID].Count;// 本 cell 内的 草的数量;

            // ============================================================================================
            // batch n dispatchs into 1 dispatch, if memory is continuous in allInstancesPosWSBuffer
            // 将内存连续的数次 dispatch 合并为一次;
            if(shouldBatchDispatch)
            {
                while( ( i < visibleCellIDList.Count - 1 ) && // test this first to avoid out of bound access to visibleCellIDList
                       ( visibleCellIDList[i + 1] == visibleCellIDList[i] + 1 ) // 如果 [i] 和 [i+1] 两个 cell 是连续的; 意味着可以 batch;
                )
                {
                    jobLength += cellPosWSsList[visibleCellIDList[i + 1]].Count;
                    i++;
                }
            }
            
            // 现在, jobLength 存储了 数个 cell 里所有草的个数;
            //Debug.Log(" 本次 dispatch 处理了多少个草: " + jobLength);

            //============================================================================================
            // 真的调用 compute shader 的 kernel: CSMain();
            // 定义了一个 (x,1,1) group
            // disaptch.X division number must match numthreads.x in compute shader (e.g. 64)
            cullingComputeShader.Dispatch(
                0,                                          // kernel idx; 目前只有一个 kernel
                Mathf.CeilToInt(jobLength / numthreads.x ), // threadGroupsX: Number of work groups in the X dimension.  大于等于 f 的整数
                1,                                          // threadGroupsY: Number of work groups in the Y dimension.
                1                                           // threadGroupsZ: Number of work groups in the Z dimension.
            );
        }
        

        // 执行完上述 Dispatch() 之后, visibleInstancesOnlyPosWSIDBuffer 会被填入 本帧可见的 每个草的 idx 值; (在 allInstancesPosWSBuffer 内的 idx 值)

        //====================================================================================
        // Final: 1 big DrawMeshInstancedIndirect draw call 
        //====================================================================================
        // GPU per instance culling finished, copy visible count to argsBuffer, to setup DrawMeshInstancedIndirect's draw amount 
        // 重写 argsBuffer 的 第 2 个元素 为: "visibleInstancesOnlyPosWSIDBuffer 的 元素个数值";
        // 也就是本次 instancing draw 批量绘制的 元素的个数;
        ComputeBuffer.CopyCount(visibleInstancesOnlyPosWSIDBuffer, argsBuffer, 4); // 向后偏移 4-bytes,     
        
        // 一整个草地 xz正方形 的 包围盒;  
        // 若 camera frustum 和这个 bound 不相交, 那么下面的 DrawMeshInstancedIndirect() 甚至不会执行渲染;
        Bounds renderBound = new Bounds();
        renderBound.SetMinMax(
            new Vector3(minX, 0, minZ), 
            new Vector3(maxX, 0, maxZ)
        );
        
        // gpu instancing, 绘制很多个重复的 mesh; 此函数底层依赖 compute shader;
        Graphics.DrawMeshInstancedIndirect(
            GetGrassMeshCache(),    // 一个草的 mesh, 三角形
            0,                      // subMeshidx
            material,               // material
            renderBound,            // bounds
            argsBuffer,             // bufferWithArgs; 这个 buffer 的配置是必须固定的;
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

        if (visibleInstancesOnlyPosWSIDBuffer != null)
            visibleInstancesOnlyPosWSIDBuffer.Release();
        visibleInstancesOnlyPosWSIDBuffer = null;

        if (argsBuffer != null)
            argsBuffer.Release();
        argsBuffer = null;

        isBuffersPrepared = false;
    }


    Mesh GetGrassMeshCache()
    {
        return MeshCreater.GetGrassMesh_Diamond();
    }
}
