# The RTHandle system

管理渲染目标是任何渲染管线中的重要部分。在一个复杂的渲染管线中，存在许多相互依赖的渲染通道使用许多不同的渲染纹理，因此拥有一个可维护且可扩展的系统以便于内存管理非常重要。

一个最大的问题发生在渲染管线使用许多不同的摄像机，每个摄像机都有自己的分辨率时。例如，用于屏幕外渲染的摄像机或实时反射探头。在这种情况下，如果系统为每个摄像机独立分配渲染纹理，总的内存量将增加到无法管理的水平。这对于使用许多中间渲染纹理的复杂渲染管线尤其糟糕。Unity可以使用临时渲染纹理，但不幸的是，它们不适合这种用例，因为临时渲染纹理只有在新的渲染纹理使用完全相同的属性和分辨率时才能重用内存。这意味着当使用两种不同分辨率渲染时，Unity使用的总内存量是所有分辨率的总和。

为了解决渲染纹理内存分配的这些问题，Unity的Scriptable Render Pipeline包括了RTHandle系统。这个系统是一个在Unity的RenderTexture API之上的抽象层，它自动处理渲染纹理管理。

**RTHandle 系统的工作原理：**

1. **自动内存管理：** RTHandle系统自动管理渲染纹理的大小和分辨率，允许动态调整以适应不同摄像机和不同渲染目标的需求。这通过减少为每个渲染目标创建新纹理的需要来降低内存使用。

2. **分辨率独立性：** RTHandle支持分辨率独立性，意味着可以为不同的渲染目标使用不同的分辨率，而不需要为每种分辨率分配单独的纹理。

3. **资源重用：** 一旦某个摄像机或渲染目标不再需要特定的渲染纹理，RTHandle系统可以将这些资源回收并重新分配给其他需要的部分，从而优化资源使用。

4. **简化API：** RTHandle提供一套简化的API来创建和管理渲染纹理，这使得开发者可以更容易地集成和使用这一系统，而不需要深入了解底层的RenderTexture细节。

通过使用RTHandle系统，Unity的开发者可以更有效地管理复杂渲染管线中的渲染目标，从而提高性能并减少内存占用。这种系统的引入对于开发需要处理多个渲染目标和高动态范围图像的高级图形应用尤其重要。

##  RTHandle system fundamentals

这份文档描述了RTHandle系统的主要原则。

RTHandle系统是基于Unity的RenderTexture API的一个抽象层。它使得在使用不同分辨率的摄像机之间重用渲染纹理变得简单。以下是RTHandle系统工作方式的基础原则：

1. **渲染纹理的分配改变**：您不再自行分配具有固定分辨率的渲染纹理。而是声明一个与给定分辨率下的全屏相关的比例的渲染纹理。RTHandle系统只为整个渲染管线分配一次纹理，以便它可以为不同的摄像机重用。

2. **参考尺寸的概念**：这是应用程序用于渲染的分辨率。在渲染每个摄像机的特定分辨率之前，您负责声明它。关于如何做到这一点，请参阅“更新RTHandle系统”部分。

3. **内部跟踪**：RTHandle系统内部跟踪您声明的最大参考尺寸。它使用这个作为渲染纹理的实际尺寸。最大参考尺寸是最大尺寸。

4. **新参考尺寸的声明**：每次您声明新的渲染参考尺寸时，RTHandle系统会检查它是否大于当前记录的最大参考尺寸。如果是，RTHandle系统会重新分配所有渲染纹理来适应新的尺寸，并用新的尺寸替换最大参考尺寸。

以下是此过程的一个例子。当您分配主颜色缓冲时，它使用1的比例，因为它是全屏纹理。您希望按屏幕分辨率渲染它。一个四分之一分辨率透明度通道的降低分辨率缓冲区将为x轴和y轴使用0.5的比例。RTHandle系统在内部使用您为渲染纹理声明的比例乘以最大参考尺寸来分配渲染纹理。之后，在每个摄像机渲染前，您告诉系统当前的参考尺寸是多少。基于该参考尺寸和所有纹理的缩放因子，RTHandle系统决定是否需要重新分配渲染纹理。如上所述，如果新的参考尺寸大于当前的最大参考尺寸，RTHandle系统将重新分配所有渲染纹理。通过这样做，RTHandle系统最终会得到所有渲染纹理的稳定最大分辨率，这很可能是您主摄像机的分辨率。

关键的一点是，渲染纹理的实际分辨率不一定与当前视口相同：它可以更大。当您使用RTHandles编写渲染器时，这有一些影响，RTHandle系统的使用文档会进行说明。

RTHandleSystem还允许您以固定大小分配纹理。在这种情况下，RTHandle系统永远不会重新分配纹理。这使您可以一致地使用RTHandle API，无论是RTHandle系统管理的自动调整大小的纹理，还是您管理的常规固定大小纹理。

##  Using the RTHandle system

这个页面介绍了如何在您的渲染管线中使用RTHandle系统来管理渲染纹理。关于RTHandle系统的信息，请参阅RTHandle系统和RTHandle系统基础知识。

**初始化RTHandle系统**
与RTHandles相关的所有操作都需要RTHandleSystem类的一个实例。这个类包含分配RTHandles、释放RTHandles以及设置帧参考尺寸所需的所有API。这意味着您必须在您的渲染管线中创建并维护一个RTHandleSystem实例，或者使用本节后面提到的静态RTHandles类。要创建自己的RTHandleSystem实例，请参见以下代码示例：

```python
RTHandleSystem m_RTHandleSystem = new RTHandleSystem();
m_RTHandleSystem.Initialize(Screen.width, Screen.height);
```

当您初始化系统时，您必须提供起始分辨率。上述代码示例使用了屏幕的宽度和高度。由于RTHandle系统只在摄像机需要比当前最大尺寸更大的分辨率时重新分配渲染纹理，所以内部RTHandle的分辨率只能从您在这里传入的值增加。最好的做法是将这个分辨率初始化为主显示器的分辨率。这意味着系统不需要在应用程序开始时不必要地重新分配渲染纹理（并导致不希望的内存尖峰）。

您只需在应用程序开始时调用一次Initialize函数。之后，您可以使用已初始化的实例来分配纹理。

由于您从同一个RTHandleSystem实例分配大多数RTHandles，RTHandle系统还通过静态RTHandles类提供一个默认的全局实例。这使您可以使用与实例相同的API，而不必担心实例的生命周期。使用静态实例，初始化变为以下代码：

```python
RTHandles.Initialize(Screen.width, Screen.height);
```

本页其余部分的代码示例使用默认的全球实例。

**更新RTHandle系统**
在使用摄像机渲染之前，您需要设置RTHandle系统使用的分辨率作为参考尺寸。要做到这一点，请调用SetReferenceSize函数。

```python
RTHandles.SetReferenceSize(width, height);
```

调用这个函数有两个效果：

1. 如果您提供的新参考尺寸比当前的大，RTHandle系统会内部重新分配所有渲染纹理以匹配新尺寸。
2. 之后，RTHandle系统会更新内部属性，以便在系统将RTHandles用作活动渲染纹理时设置视口和渲染纹理的比例。

这里的关键操作是在渲染之前正确设置参考尺寸，这样可以确保RTHandles的按需调整和适配，从而提高渲染效率并优化内存使用。

本页面讲解了如何在您的渲染管线中使用RTHandle系统来管理渲染纹理。以下内容详细介绍了如何初始化、分配、释放RTHandles，以及如何在渲染中使用RTHandles。

**分配和释放RTHandles**

在初始化RTHandleSystem实例之后，无论是您自己的实例还是静态默认实例，您都可以使用它来分配RTHandles。

分配RTHandle主要有三种方式，它们都使用RTHandleSystem实例上的同一个Alloc方法。这些函数的大多数参数与常规Unity RenderTexture的参数相同，更多信息请参见RenderTexture API文档。本节重点介绍与RTHandle大小相关的参数：

- **Vector2 scaleFactor**: 这种变体要求宽度和高度的常量2D比例。RTHandle系统使用此比例根据最大参考尺寸计算纹理的分辨率。例如，比例为(1.0f, 1.0f)生成全屏纹理。比例为(0.5f, 0.5f)生成四分之一分辨率的纹理。
- **ScaleFunc scaleFunc**: 如果您不想使用常量比例来计算RTHandle的大小，您可以提供一个函数（functor），该函数计算纹理的大小。此函数应接受一个Vector2Int参数，即最大参考尺寸，并返回一个Vector2Int，表示您希望纹理具有的大小。
- **int width, int height**: 这是用于固定大小纹理的。如果像这样分配纹理，它的行为就像任何常规RenderTexture一样。

还有其他重载函数，它们可以从RenderTargetIdentifier、RenderTextures或Textures创建RTHandles。当您希望使用RTHandle API与所有纹理交互时，这些重载非常有用，即使纹理可能不是实际的RTHandle。

以下代码示例包含使用Alloc函数的示例：

```python
# 简单缩放
RTHandle simpleScale = RTHandles.Alloc(Vector2.one, depthBufferBits: DepthBits.Depth32, dimension: TextureDimension.Tex2D, name: "CameraDepthStencil");

# 函数
Vector2Int ComputeRTHandleSize(Vector2Int screenSize)
{
    return DoSpecificResolutionComputation(screenSize);
}

RTHandle rtHandleUsingFunctor = RTHandles.Alloc(ComputeRTHandleSize, colorFormat: GraphicsFormat.R32_SFloat, dimension: TextureDimension.Tex2D);

# 固定大小
RTHandle fixedSize = RTHandles.Alloc(256, 256, colorFormat: GraphicsFormat.R8G8B8A8_UNorm, dimension: TextureDimension.Tex2D);
```

当您不再需要特定的RTHandle时，可以释放它。为此，请调用Release方法。

```python
myRTHandle.Release();
```

**使用RTHandles**

分配了RTHandle后，您可以像使用常规RenderTexture一样使用它。存在到RenderTargetIdentifier和RenderTexture的隐式转换，这意味着您可以将它们与相关的常规Unity API一起使用。

但是，当您使用RTHandle系统时，RTHandle的实际分辨率可能与当前分辨率不同。例如，如果主摄像机以1920x1080渲染，而次要摄像机以512x512渲染，所有RTHandle的分辨率都基于1920x1080分辨率，即使在较低分辨率下渲染也是如此。因此，在将RTHandle设置为渲染目标时，请小心。CoreUtils类中有许多API可以帮助您处理这些问题。例如：

```python
public static void SetRenderTarget(CommandBuffer cmd, RTHandle buffer, ClearFlag clearFlag, Color clearColor, int miplevel = 0, CubemapFace cubemapFace = CubemapFace.Unknown, int depthSlice = -1)
```

此功能将RTHandle设置为活动渲染目标，但还根据RTHandle的比例和当前参考尺寸（而不是最大尺寸）设置视口。

例如，当参考尺寸为512x512时，即使最大尺寸为1920x1080，比例为(1.0f, 1.0f)的纹理也使用512x512尺寸并因此设置512x512视口。比例为(0.5f, 0.5f)的纹理设置了256x256的视口，依此类推。这意味着，使用这些辅助函数时，RTHandle系统会根据RTHandle参数生成正确的视口。

本节内容专注于具体的SRP（Scriptable Render Pipeline）和使用RTHandle的高级技术，为处理特定摄像机和动态分辨率需求提供指导。

**自定义SRP的特定信息**

默认情况下，SRP不提供着色器常量。因此，当您在自己的SRP中使用RTHandles时，必须自己向着色器提供这些常量。

**摄像机特定的RTHandles**

大多数渲染循环使用的渲染纹理可以由所有摄像机共享。如果它们的内容不需要从一帧传到另一帧，这种做法是可行的。然而，某些渲染纹理需要持久性。一个典型的例子是在后续帧中使用主颜色缓冲进行时间抗锯齿处理。这意味着摄像机不能与其他摄像机共享其RTHandle。大多数情况下，这也意味着这些RTHandles必须至少是双缓冲的（在当前帧写入，在上一帧读取）。为解决这个问题，RTHandle系统包括了BufferedRTHandleSystems。

BufferedRTHandleSystem是一个可以多缓冲RTHandles的RTHandleSystem。其原理是通过唯一ID识别缓冲，并提供API来分配同一缓冲的多个实例，然后从之前的帧中检索它们。这些是历史缓冲。通常，您必须为每个摄像机分配一个BufferedRTHandleSystem。每个系统拥有其特定摄像机的RTHandles。

并非每个摄像机都需要历史缓冲。例如，如果摄像机不需要时间抗锯齿，您不需要为其分配BufferedRTHandleSystem。历史缓冲需要内存，这意味着您可以通过不为不需要它们的摄像机分配历史缓冲来节省内存。另一个后果是，系统仅在缓冲所对应的摄像机的分辨率下分配历史缓冲。如果主摄像机是1920x1080，而另一个摄像机以256x256渲染并需要一个历史颜色缓冲，第二个摄像机仅使用256x256的缓冲，而不是像非摄像机特定的RTHandles那样使用1920x1080的缓冲。要创建BufferedRTHandleSystem的实例，请参见以下代码示例：

```python
BufferedRTHandleSystem m_HistoryRTSystem = new BufferedRTHandleSystem();
```

使用BufferedRTHandleSystem分配RTHandle的过程与使用普通RTHandleSystem的过程不同：

```python
public void AllocBuffer(int bufferId, Func<RTHandleSystem, int, RTHandle> allocator, int bufferCount);
```

`bufferId`是系统用来识别缓冲的唯一ID。`allocator`是您提供的函数，用于在需要时分配RTHandles（并非所有实例都是预先分配的），`bufferCount`是请求的实例数量。

从那里，您可以像下面这样通过其ID和实例索引检索每个RTHandle：

```python
public RTHandle GetFrameRT(int bufferId, int frameIndex);
```

帧索引介于零到缓冲数减一之间。零总代表当前帧的缓冲，一代表前一帧的缓冲，依此类推。

要释放缓冲的RTHandle，调用BufferedRTHandleSystem上的Release函数，并传入要释放的缓冲的ID：

```python
public void ReleaseBuffer(int bufferId);
```

就像为常规RTHandleSystems提供参考尺寸一样，您必须为每个BufferedRTHandleSystem实例提供这一参考尺寸。