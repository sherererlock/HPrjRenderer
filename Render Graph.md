# Render Graph

## Benefits of the render graph system

###  Efficient memory management

当您手动管理资源分配时，您需要考虑所有渲染功能同时激活的情况，因此要为最坏的情况进行资源配置。当某些渲染功能未激活时，处理它们的资源虽然存在，但渲染管线并未使用。渲染图只会分配当前帧实际使用的资源。这减少了渲染管线的内存占用，意味着无需创建复杂的逻辑来处理资源分配。高效的内存管理的另一个好处是，由于渲染图可以高效地复用资源，这使得有更多的资源可以用来为您的渲染管线创建新的功能。

### Automatic synchronization point generation

异步计算队列可以与常规图形工作负载并行运行，因此可能减少处理渲染管线所需的总GPU时间。然而，手动定义和维护异步计算队列与常规图形队列之间的同步点可能会很困难。渲染图自动化了这一过程，并使用渲染管线的高级声明，生成计算队列与图形队列之间正确的同步点。

### Maintainability

渲染管线维护中最复杂的问题之一是资源管理。由于渲染图内部管理资源，因此极大简化了渲染管线的维护。使用RenderGraph API，您可以编写高效的独立渲染模块，这些模块明确声明它们的输入和输出，并能够在渲染管线的任何位置插入使用。

# Render graph fundamentals

## Main principles

在您使用RenderGraph API编写渲染通道之前，需要了解以下基本原则：

1. 您不再直接处理资源，而是使用渲染图系统特定的句柄。所有RenderGraph API都使用这些句柄来操作资源。渲染图管理的资源类型包括RTHandles（渲染目标句柄）、ComputeBuffers（计算缓冲区）和RendererLists（渲染器列表）。
2. 实际的资源引用只能在渲染通道的执行代码中访问。
3. 框架需要对渲染通道进行明确的声明。每个渲染通道必须说明它从哪些资源中读取和/或写入。
4. 渲染图的每次执行之间没有持久性。这意味着您在渲染图的一次执行中创建的资源不能延续到下一次执行。
5. 对于需要持久性的资源（例如，从一个帧到另一个帧），您可以像常规资源一样在渲染图外部创建它们，并将它们导入。它们在依赖跟踪方面的表现与其他渲染图资源相同，但图形不处理它们的生命周期。
6. 渲染图主要使用RTHandles来处理纹理资源。这对于如何编写着色器代码以及如何设置它们有一些影响。

## Resource Management

渲染图系统通过对整个帧的高级表示来计算每个资源的生命周期。这意味着，当您通过RenderGraph API创建一个资源时，渲染图系统并不会在那时创建资源。相反，API返回一个代表该资源的句柄，您随后可以使用这个句柄与所有RenderGraph API配合使用。渲染图只会在需要写入资源的第一个通道之前创建资源。在这种情况下，“创建”并不一定意味着渲染图系统分配资源。而是意味着它提供必要的内存来表示资源，以便在渲染通道中使用该资源。同样地，它也会在最后一个需要读取该资源的通道之后释放资源内存。通过这种方式，渲染图系统可以根据您在通道中声明的内容，以最高效的方式重用内存。如果渲染图系统没有执行需要特定资源的通道，则系统不会为该资源分配内存。

## Render graph execution overview

渲染图的执行是一个三步骤过程，渲染图系统每一帧都会从头开始完成。这是因为渲染图可以根据用户的行为，从一帧到另一帧动态变化。

### Setup

第一步是设置所有的渲染通道。在这一步中，您需要声明所有要执行的渲染通道以及每个渲染通道使用的资源。

###  Compilation

第二步是编译图表。在这一步中，如果没有其他渲染通道使用其输出，渲染图系统会剔除某些渲染通道。这允许有较少组织的设置，因为您可以在设置图表时减少特定的逻辑。一个好的例子是调试渲染通道。如果您声明了一个产生调试输出但不显示到后缓冲区的渲染通道，渲染图系统会自动剔除该通道。

这一步还计算资源的生命周期。这使得渲染图系统能够以高效的方式创建和释放资源，同时在执行异步计算管线上的通道时计算正确的同步点。

### Execution

最后一步是执行图表。渲染图系统按声明的顺序执行所有未被剔除的渲染通道。在每个渲染通道之前，渲染图系统会创建适当的资源，并在渲染通道之后释放这些资源，前提是后续的渲染通道不再使用这些资源。这样的处理确保了资源的高效利用和正确的执行顺序。

# Writing a render pipeline

###  Initialization and cleanup of Render Graph

首先，您的渲染管线需要维护至少一个RenderGraph实例。这是API的主要入口点。您可以使用多个渲染图实例，但请注意，Unity不会在RenderGraph实例之间共享资源，因此为了优化内存使用，建议只使用一个实例。

```c#
using UnityEngine.Rendering.RenderGraphModule;

public class MyRenderPipeline : RenderPipeline
{
    RenderGraph m_RenderGraph;

    void InitializeRenderGraph()
    {
        m_RenderGraph = new RenderGraph(“MyRenderGraph”);
    }

    void CleanupRenderGraph()
    {
        m_RenderGraph.Cleanup();
          m_RenderGraph = null;
    }
}
```

为了初始化一个RenderGraph实例，可以调用构造函数，并可选地传入一个名称来标识渲染图。这还会在SRP Debug窗口中注册一个专属于渲染图的面板，这对于调试RenderGraph实例非常有用。当您销毁一个渲染管线时，需要调用RenderGraph实例的Cleanup()方法，以正确释放渲染图分配的所有资源。

### Starting a render graph

在您向渲染图添加任何渲染通道之前，首先需要通过调用BeginRecording方法来初始化渲染图。一旦所有渲染通道都被添加到渲染图中，您可以通过调用EndRecordingAndExecute方法来执行它。

有关BeginRecording方法参数的详细信息，请参阅API文档。

```c#
var renderGraphParams = new RenderGraphParameters()
{
    scriptableRenderContext = renderContext,
    commandBuffer = cmd,
    currentFrameIndex = frameIndex
};

m_RenderGraph.BeginRecording(renderGraphParams);
// Add your passes here
m_RenderGraph.EndRecordingAndExecute();
```

###  Creating resources for the render graph

使用渲染图时，您永远不会直接分配资源。相反，RenderGraph实例会处理自己的资源分配和处置。要声明资源并在渲染通道中使用它们，您需要使用返回资源句柄的渲染图特定API。

渲染图使用的两种主要资源类型包括：
- 内部资源：这些资源是渲染图执行内部的，您无法在RenderGraph实例外部访问它们。您也不能将这些资源从一个图的执行传递到另一个。渲染图负责这些资源的生命周期。
- 导入资源：这些资源通常来自渲染图执行外部。典型的例子包括由相机提供的后缓冲区，或者您希望图跨多个帧使用的缓冲区，用于时域效果（如使用相机颜色缓冲区进行时域抗锯齿）。您负责处理这些资源的生命周期。

创建或导入资源后，渲染图系统将其表示为特定于资源类型的句柄（TextureHandle、BufferHandle或RendererListHandle）。这样，渲染图可以在其所有API中以相同的方式使用内部和导入资源。

```c#
public TextureHandle RenderGraph.CreateTexture(in TextureDesc desc);
public BufferHandle RenderGraph.CreateComputeBuffer(in ComputeBufferDesc desc)
public RendererListHandle RenderGraph.CreateRendererList(in RendererListDesc desc);

public TextureHandle RenderGraph.ImportTexture(RTHandle rt);
public TextureHandle RenderGraph.ImportBackbuffer(RenderTargetIdentifier rt);
public BufferHandle RenderGraph.ImportBuffer(ComputeBuffer computeBuffer);
```

创建资源的主要方式如上所述，但这些功能还有变体。有关完整列表，请参阅API文档。注意，用于导入相机后缓冲区的特定函数是RenderTargetIdentifier。

创建资源时，每个API都需要一个描述符结构作为参数。这些结构中的属性与它们代表的资源（分别为RTHandle、ComputeBuffer和RendererLists）的属性相似。然而，有些属性是特定于渲染图纹理的。

以下是一些最重要的属性：
- clearBuffer：此属性告诉图是否在创建时清除缓冲区。这是使用渲染图时应如何清除纹理的方法。这一点很重要，因为渲染图池化资源，这意味着任何创建纹理的通道都可能得到一个已存在的、内容未定义的纹理。
- clearColor：此属性存储清除缓冲区时使用的颜色（如果适用）。

还有两个特定于纹理的渲染图通过TextureDesc构造函数暴露的概念：
- xrReady：这个布尔值告诉图这个纹理是否用于XR渲染。如果为真，渲染图会将纹理创建为一个数组，用于渲染每个XR眼睛。
- dynamicResolution：这个布尔值告诉图在应用使用动态分辨率时是否需要动态调整这个纹理的大小。如果为假，纹理不会自动缩放。

您可以在渲染通道之外的设置代码中创建资源，但不能在渲染代码中创建。

在所有渲染通道外部创建资源可以用于第一个通道使用的资源取决于可能经常变化的代码逻辑的情况。在这种情况下，您必须在这些通道之前创建资源。一个好的例子是使用颜色缓冲区进行延迟照明通道或正向照明通道。这两个通道都会写入颜色缓冲区，但Unity只会根据相机选择的当前渲染路径执行其中一个。在这种情况下，您将在两个通道外部创建颜色缓冲区并将其作为参数传递给正确的通道。

在渲染通道内部创建资源通常用于渲染通道自身产生的资源。例如，一个模糊通道需要一个已存在的输入纹理，但会自己创建输出，并在渲染通道结束时返回它。

注意，这样创建资源并不会每帧分配GPU内存。相反，渲染图系统会重用池化内存。在渲染图的上下文中，应将资源创建更多地视为渲染通道中的数据流，而不是实际分配。如果一个渲染通道创建了一个全新的输出，那么它在渲染图中“创建”了一个新的纹理。

### Writing a render pass

在Unity可以执行渲染图之前，必须声明所有的渲染通道。你需要以两个部分编写一个渲染通道：设置和渲染。

**设置阶段：**  
在这个阶段，你需要声明渲染通道以及执行所需的所有数据。渲染图通过一个特定于渲染通道的类来表示数据，该类包含所有相关的属性。这些可以是常规的C#结构（如struct，PoDs等）和渲染图资源句柄。这个数据结构在实际的渲染代码中是可访问的。

```c#
class MyRenderPassData
{
    public float parameter;
    public TextureHandle inputTexture;
    public TextureHandle outputTexture;
}
```

定义完通道数据后，你可以声明渲染通道本身：

```c#
using (var builder = renderGraph.AddRenderPass<MyRenderPassData>("My Render Pass", out var passData))
{
        passData.parameter = 2.5f;
    passData.inputTexture = builder.ReadTexture(inputTexture);

    TextureHandle output = renderGraph.CreateTexture(new TextureDesc(Vector2.one, true, true)
                        { colorFormat = GraphicsFormat.R8G8B8A8_UNorm, clearBuffer = true, clearColor = Color.black, name = "Output" });
    passData.outputTexture = builder.WriteTexture(output);

    builder.SetRenderFunc(myFunc); // details below.
}
```

**渲染通道的定义：**  
你在围绕AddRenderPass函数的using作用域中定义渲染通道。在作用域结束时，渲染图将渲染通道添加到渲染图的内部结构中，以便稍后处理。

`builder`变量是RenderGraphBuilder的一个实例。这是建立与渲染通道相关信息的入口点。其中有几个重要部分：

- **声明资源使用：** 这是RenderGraph API的最重要的方面之一。在这里，你需要明确声明渲染通道是读取资源还是写入资源，或者两者都需要。这允许渲染图对整个渲染帧有一个全面的视图，从而确定GPU内存的最佳使用和各个渲染通道之间的同步点。
- **声明渲染函数：** 这是你调用图形命令的函数。它接收你为渲染通道定义的传递数据作为参数，以及渲染图上下文。你通过SetRenderFunc设置渲染通道的渲染函数，该函数在图编译后运行。
- **创建临时资源：** 临时或内部资源是你仅为此渲染通道的持续时间创建的资源。你在builder中而非渲染图本身创建它们，以反映它们的生命周期。创建临时资源使用与RenderGraph API中相同的参数。当一个通道使用不应该在通道外部访问的临时缓冲区时，这特别有用。在声明临时资源的通道之外，该资源的句柄变为无效，如果你尝试使用它，Unity会抛出错误。

`passData`变量是你在声明通道时提供的类型的实例。这是你设置渲染代码可以访问的数据的地方。注意，渲染图不会立即使用passData的内容，而是在注册所有通道后以及渲染图编译和执行后的帧中使用。这意味着passData存储的任何引用必须在整个帧中保持恒定。否则，如果你在渲染通道执行前更改内容，它在渲染通道中的内容将不正确。因此，最佳做法是仅在passData中存储值类型，除非你确定一个引用会在通道执行结束前保持不变。

有关RenderGraphBuilder API的概述，请参见下表。有关更多详情，请查看API文档：

| 函数                                                         | 功能                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `TextureHandle ReadTexture(in TextureHandle input)`          | 声明渲染通道从输入纹理读取。                                 |
| `TextureHandle WriteTexture(in TextureHandle input)`         | 声明渲染通道写入输入纹理。                                   |
| `TextureHandle UseColorBuffer(in TextureHandle input, int index)` | 类似于WriteTexture，但还会在通道开始时自动将纹理绑定为渲染纹理。 |
| `TextureHandle UseDepthBuffer(in TextureHandle input, DepthAccess flags)` | 类似于WriteTexture，但还会自动将纹理绑定为深度纹理。         |
| `TextureHandle CreateTransientTexture(in TextureDesc desc)`  | 创建一个临时纹理。这个纹理存在于通道的持续时间。             |
| `RendererListHandle UseRendererList(in RendererListHandle input)` | 声明此渲染通道使用你传入的Renderer List。渲染通道使用RendererList.Draw命令来渲染列表。 |
| `BufferHandle ReadComputeBuffer(in BufferHandle input)`      | 声明渲染通道从输入的ComputeBuffer读取。                      |
| `BufferHandle WriteComputeBuffer(in BufferHandle input)`     | 声明渲染通道写入输入的ComputeBuffer。                        |
| `BufferHandle CreateTransientComputeBuffer(in BufferDesc desc)` | 创建一个临时Compute Buffer。这个纹理存在于Compute Buffer的持续时间。 |
| `void SetRenderFunc(RenderFunc renderFunc)`                  | 设置渲染通道的渲染函数。                                     |
| `void EnableAsyncCompute(bool value)`                        | 声明渲染通道在异步计算管线上运行。                           |
| `void AllowPassCulling(bool value)`                          | 指定是否允许Unity剔除渲染通道（默认为true）。当渲染通道有副作用且你永远不希望渲染图系统剔除时，这会很有用。 |
| `void EnableFoveatedRasterization(bool value)`               | 声明渲染通道启用注视渲染功能。                               |

以上是对设置和定义渲染通道的详细介绍，这是在Unity中使用渲染图进行高效渲染的关键步骤。

####  Rendering Code

完成设置之后，您可以通过RenderGraphBuilder上的`SetRenderFunc`方法声明用于渲染的函数。您分配的函数必须使用以下签名：

```c#
delegate void RenderFunc<PassData>(PassData data, RenderGraphContext renderGraphContext) where PassData : class, new();
```

您可以传入一个静态函数或一个lambda函数作为渲染函数。使用lambda函数的好处是它可以带来更好的代码清晰度，因为渲染代码就在设置代码旁边。

请注意，如果您使用lambda，要非常小心不要从函数的主作用域捕获任何参数，因为这会生成垃圾，Unity将在垃圾收集期间定位并释放这些垃圾。如果您使用Visual Studio并将鼠标悬停在箭头`=>`上，它会告诉您lambda是否捕获了作用域中的任何内容。避免访问成员或成员函数，因为使用它们会捕获`this`。

渲染函数接受两个参数：

- **PassData data**: 此数据是您在声明渲染通道时传入的类型。在这里，您可以访问在设置阶段初始化的属性，并用它们来进行渲染代码。
- **RenderGraphContext renderGraphContext**: 这存储了对ScriptableRenderContext和CommandBuffer的引用，它们提供实用功能并允许您编写渲染代码。

**在渲染通道中访问资源**

在渲染函数内部，您可以访问存储在passData中的所有渲染图资源句柄。转换到实际资源是自动的，所以，每当一个函数需要一个RTHandle、ComputeBuffer或RendererList时，您可以传递句柄，渲染图会隐式地将句柄转换为实际资源。请注意，在渲染函数外部进行这种隐式转换会导致异常。这种异常是因为在渲染外部，渲染图可能还没有分配这些资源。

**使用RenderGraphContext**

RenderGraphContext提供了编写渲染代码所需的各种功能。其中最重要的是ScriptableRenderContext和CommandBuffer，您可以使用它们调用所有渲染命令。

RenderGraphContext还包含一个RenderGraphObjectPool。这个类可以帮助您管理渲染代码可能需要的临时对象。

**获取临时函数**

在渲染通道中特别有用的两个函数是`GetTempArray`和`GetTempMaterialPropertyBlock`。

```
T[] GetTempArray<T>(int size);
MaterialPropertyBlock GetTempMaterialPropertyBlock();
```

`GetTempArray`返回一个临时数组，类型为T，大小为size。这对于分配临时数组以将参数传递给材料或创建RenderTargetIdentifier数组来创建多目标渲染设置非常有用，无需自己管理数组的生命周期。

`GetTempMaterialPropertyBlock`返回一个干净的材料属性块，您可以使用它来设置Material的参数。这是特别重要的，因为不止一个通道可能会使用材料，而且每个通道都可能以不同的参数使用它。由于渲染代码执行通过命令缓冲区推迟，因此将材料属性块复制到命令缓冲区是必须的，以保持执行时数据的完整性。

渲染图在通道执行后自动释放和池化这两个函数返回的所有资源。这意味着您不必自己管理它们，也不会产生垃圾。

#### Example render pass

The following code example contains a render pass with a setup and render function:

```c#
TextureHandle MyRenderPass(RenderGraph renderGraph, TextureHandle inputTexture, float parameter, Material material)
{
    using (var builder = renderGraph.AddRenderPass<MyRenderPassData>("My Render Pass", out var passData))
    {
        passData.parameter = parameter;
        passData.material = material;

        // Tells the graph that this pass will read inputTexture.
        passData.inputTexture = builder.ReadTexture(inputTexture);

        // Creates the output texture.
        TextureHandle output = renderGraph.CreateTexture(new TextureDesc(Vector2.one, true, true)
                        { colorFormat = GraphicsFormat.R8G8B8A8_UNorm, clearBuffer = true, clearColor = Color.black, name = "Output" });
        // Tells the graph that this pass will write this texture and needs to be set as render target 0.
        passData.outputTexture = builder.UseColorBuffer(output, 0);

        builder.SetRenderFunc(
        (MyRenderPassData data, RenderGraphContext ctx) =>
        {
            // Render Target is already set via the use of UseColorBuffer above.
            // If builder.WriteTexture was used, you'd need to do something like that:
            // CoreUtils.SetRenderTarget(ctx.cmd, data.output);

            // Setup material for rendering
            var materialPropertyBlock = ctx.renderGraphPool.GetTempMaterialPropertyBlock();
            materialPropertyBlock.SetTexture("_MainTexture", data.input);
            materialPropertyBlock.SetFloat("_FloatParam", data.parameter);

            CoreUtils.DrawFullScreen(ctx.cmd, data.material, materialPropertyBlock);
        });

        return output;
    }
}

```

### Ending the frame

在您的应用程序的运行过程中，渲染图需要分配各种资源。这些资源可能被使用一段时间，之后可能不再需要。为了释放这些资源，一旦一帧结束，就调用`EndFrame()`方法。这将取消分配自上一帧以来渲染图未使用的任何资源。这也执行渲染图在帧结束时所需的所有内部处理。

请注意，您应该每帧只调用这个方法一次，并且在所有渲染完成后再调用（例如，在最后一个摄像机渲染完成后）。这是因为不同的摄像机可能有不同的渲染路径，因此需要不同的资源。在每个摄像机渲染后立即调用清理可能导致渲染图过早释放资源，尽管这些资源可能对下一个摄像机而言是必需的。

调用`EndFrame()`的正确时机对于确保资源有效使用和避免潜在的资源竞争或错误非常关键。这个方法帮助渲染图维护其内部资源池，确保资源在不再需要时可以被有效地回收和重用，从而优化内存使用并减少性能开销。