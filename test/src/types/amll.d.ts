/**
 * AMLL (Apple Music-like Lyrics) 相关类型定义
 */

/**
 * 歌词播放器引用类型
 */
export interface LyricPlayerRef {
  setCurrentTime?: (time: number) => void;
  setPlaying?: (playing: boolean) => void;
  lyricPlayer?: { value?: any };
}

/**
 * 歌词单词类型
 */
export interface LyricWord {
  word: string;
  startTime: number;
  endTime: number;
}

/**
 * 歌词行类型
 */
export interface LyricLine {
  startTime: number;
  endTime: number;
  words: LyricWord[];
  translatedLyric?: string;
  romanLyric?: string;
  isBG?: boolean;
  isDuet?: boolean;
}

/**
 * 歌词点击事件类型
 */
export interface LyricClickEvent {
  line: {
    getLine: () => LyricLine;
    lyricLine?: LyricLine;
  };
}

/**
 * 弹簧参数类型
 */
export interface SpringParam {
  mass: number; // 质量，影响弹簧的惯性
  damping: number; // 阻尼，影响弹簧的减速速度
  stiffness: number; // 刚度，影响弹簧的弹力
  soft: boolean; // 是否使用软弹簧模式
}

/**
 * 弹簧参数集合
 */
export interface SpringParams {
  posX?: SpringParam;
  posY?: SpringParam;
  scale?: SpringParam;
  rotation?: SpringParam;
}

/**
 * 背景渲染器引用类型
 */
export interface BackgroundRenderRef {
  bgRender: any;
  wrapperEl?: HTMLDivElement;
}

/**
 * 背景渲染器属性类型
 */
export interface BackgroundRenderProps {
  album?: string;
  albumIsVideo?: boolean;
  fps?: number;
  playing?: boolean;
  flowSpeed?: number;
  hasLyric?: boolean;
  lowFreqVolume?: number;
  renderScale?: number;
  staticMode?: boolean;
  renderer?: any;
}

/**
 * 歌词处理器设置类型
 */
export interface LyricsProcessorSettings {
  showYrc: boolean;
  showRoma: boolean;
  showTransl: boolean;
}

/**
 * 歌曲歌词类型
 */
export interface SongLyric {
  lrc?: Array<{time: number, content: string, tran?: string, roma?: string}>;
  yrc?: Array<{time: number, endTime?: number, content: any[], tran?: string, roma?: string}>;
  ttml?: string;
  hasYrc?: boolean;
  lrcAMData?: LyricLine[];
  yrcAMData?: LyricLine[];
}