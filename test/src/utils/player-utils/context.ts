import { isElectron } from "@/utils/helper";

/**
 * 针对单个 HTMLMediaElement 的音频图节点集合
 * - context: 全局共享的 AudioContext 实例
 * - source: 由 mediaElement 创建的源节点
 * - analyser: 频谱分析节点（频谱显示/后续处理的观察点）
 * - preGain: 均衡器前级增益（可选，启用 EQ 时存在）
 * - filters: 均衡器滤波器链（可选，启用 EQ 时存在，首尾为 shelf，中间为 peaking）
 */
export type AudioGraphNodes = {
  context: AudioContext;
  source: MediaElementAudioSourceNode;
  analyser: AnalyserNode;
  preGain?: GainNode;
  filters?: BiquadFilterNode[];
};

/**
 * AudioContextManager
 * - 单例管理器：维护一个全局 AudioContext 与每个 mediaElement 的音频图
 * - 提供：
 *   1) 基础图创建与缓存（source -> analyser）
 *   2) EQ 启用、更新、禁用（构建/修改 source -> preGain -> filters... -> analyser 链）
 *   3) 图销毁与全局销毁
 */
class AudioContextManager {
  private static instance: AudioContextManager | null = null;
  private context: AudioContext | null = null;
  private nodeMap: WeakMap<HTMLMediaElement, AudioGraphNodes> = new WeakMap();

  // 默认 10 段均衡器中心频率 (Hz)
  private readonly defaultFrequencies: number[] = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];
  // 默认 Q 值（首尾 shelf 不使用 Q）
  private readonly defaultQ: number = 1.0;

  /** 获取管理器单例 */
  static getInstance() {
    if (!AudioContextManager.instance) {
      AudioContextManager.instance = new AudioContextManager();
    }
    return AudioContextManager.instance;
  }

  /**
   * 获取或创建全局 AudioContext
   * 说明：仅在 Electron 环境中生效；浏览器端维持与现有逻辑一致不启用
   */
  getContext(): AudioContext | null {
    if (!isElectron) return null;
    if (!this.context) {
      this.context = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    return this.context;
  }

  /**
   * 获取（或为该 mediaElement 创建）基础音频图：source -> analyser
   * 不在此处连接 destination，由调用方决定是否连接到输出以避免与 HTMLAudioElement 直出叠加
   */
  getOrCreateBasicGraph(mediaElement: HTMLMediaElement): AudioGraphNodes | null {
    if (!isElectron) return null;
    const existing = this.nodeMap.get(mediaElement);
    if (existing) return existing;
    const context = this.getContext();
    if (!context) return null;
    const source = context.createMediaElementSource(mediaElement);
    const analyser = context.createAnalyser();
    analyser.fftSize = 512;
    // 默认仅连接到 analyser，是否接到 destination 由上层控制
    source.connect(analyser);
    const nodes: AudioGraphNodes = { context, source, analyser };
    this.nodeMap.set(mediaElement, nodes);
    return nodes;
  }

  // 计算 dB 到线性增益
  private dbToLinear(db: number): number {
    return Math.pow(10, db / 20);
  }

  /** 启用均衡器：source -> preGain -> filters... -> analyser（不连接 destination） */
  enableEq(
    mediaElement: HTMLMediaElement,
    options?: {
      bands?: number[]; // dB 值，与频率一一对应
      frequencies?: number[]; // 自定义中心频率
      q?: number; // peaking Q
      preamp?: number; // dB
    },
  ) {
    if (!isElectron) return null;
    const nodes = this.getOrCreateBasicGraph(mediaElement);
    if (!nodes) return null;
    const { context, source, analyser } = nodes;
    // 断开 source 直连 analyser，改为走 EQ 链
    // 如果已存在 EQ 链，先彻底移除，避免重复并联导致增益叠加
    try {
      if (nodes.filters && nodes.filters.length) nodes.filters.forEach((f) => f.disconnect());
      if (nodes.preGain) nodes.preGain.disconnect();
    } catch {
      /* empty */
    }
    try {
      source.disconnect();
    } catch {
      /* empty */
    }
    // 创建 preGain（前级增益：整体增益控制，避免各段叠加导致失真）
    const preGain = context.createGain();
    preGain.gain.value = this.dbToLinear(options?.preamp ?? 0);
    // 创建滤波器（10 段：首尾 shelf，中间 peaking）
    const freqs = options?.frequencies ?? this.defaultFrequencies;
    const gains = options?.bands ?? new Array(freqs.length).fill(0);
    const q = options?.q ?? this.defaultQ;
    const filters: BiquadFilterNode[] = freqs.map((f, i) => {
      const filter = context.createBiquadFilter();
      if (i === 0) filter.type = "lowshelf";
      else if (i === freqs.length - 1) filter.type = "highshelf";
      else filter.type = "peaking";
      filter.frequency.value = f;
      if (filter.type === "peaking") filter.Q.value = q;
      filter.gain.value = gains[i] ?? 0; // dB
      return filter;
    });
    // 连接链路：source -> preGain -> f0 -> f1 ... -> fn -> analyser
    // 注意：不在此处连接到 destination，交由上层（player）决定，防止与 HTML 元素直出叠加
    source.connect(preGain);
    let current: AudioNode = preGain;
    for (const f of filters) {
      current.connect(f);
      current = f;
    }
    current.connect(analyser);
    // 保存
    nodes.preGain = preGain;
    nodes.filters = filters;
    this.nodeMap.set(mediaElement, nodes);
    return nodes;
  }

  /**
   * 更新均衡器参数（不重建链路）
   * - bands: 各频段 dB 值（与 frequencies 对齐），直接写入 filter.gain
   * - preamp: 前级增益 dB，转换为线性增益写入 preGain.gain
   * - q: peaking 类型的 Q 值统一更新（shelf 不适用 Q）
   */
  updateEq(
    mediaElement: HTMLMediaElement,
    options: { bands?: number[]; preamp?: number; q?: number } = {},
  ) {
    const nodes = this.nodeMap.get(mediaElement);
    if (!nodes || !nodes.filters || !nodes.preGain) return;
    const { filters, preGain } = nodes;
    if (typeof options.preamp === "number") {
      preGain.gain.value = this.dbToLinear(options.preamp);
    }
    if (Array.isArray(options.bands)) {
      filters.forEach((f, idx) => {
        if (typeof options.bands![idx] === "number") f.gain.value = options.bands![idx] as number;
      });
    }
    if (typeof options.q === "number") {
      filters.forEach((f) => {
        if (f.type === "peaking") f.Q.value = options.q as number;
      });
    }
  }

  /**
   * 禁用均衡器
   * - 断开 preGain 与所有 filters，并恢复为 source -> analyser
   * - 不直接连接到 destination，由调用方按需处理
   */
  disableEq(mediaElement: HTMLMediaElement) {
    const nodes = this.nodeMap.get(mediaElement);
    if (!nodes) return;
    const { source, analyser, preGain, filters } = nodes;
    try {
      if (filters && filters.length) filters.forEach((f) => f.disconnect());
      if (preGain) preGain.disconnect();
    } catch {
      /* empty */
    }
    try {
      source.disconnect();
    } catch {
      /* empty */
    }
    source.connect(analyser);
    nodes.preGain = undefined;
    nodes.filters = undefined;
    this.nodeMap.set(mediaElement, nodes);
  }

  /**
   * 断开并移除指定元素的图（不关闭全局 context）
   * - 用于元素销毁或完全停止可视化/处理时的清理
   */
  disposeGraph(mediaElement: HTMLMediaElement) {
    const nodes = this.nodeMap.get(mediaElement);
    if (!nodes) return;
    try {
      nodes.source.disconnect();
      nodes.analyser.disconnect();
    } catch {
      /* empty */
    }
    this.nodeMap.delete(mediaElement);
  }

  /**
   * 销毁整个上下文（谨慎调用）
   * - 关闭全局 AudioContext，并清空所有节点缓存
   * - 仅在应用退出或需要彻底重建时调用
   */
  destroyAll() {
    if (this.context) {
      try {
        this.context.close();
      } catch {
        /* empty */
      }
      this.context = null;
    }
    this.nodeMap = new WeakMap();
  }
}

const audioContextManager = AudioContextManager.getInstance();
export default audioContextManager;
