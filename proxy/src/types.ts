export interface SongDto {
  id: string;
  code: string;
  title: string;
  artist: string;
  albumCover: string;
  rank: number;
}

export interface MusicUpstream {
  fetchChart(signal?: AbortSignal): Promise<SongDto[]>;
  fetchSource(code: string, signal?: AbortSignal): Promise<string>;
}

export class UpstreamError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'UpstreamError';
  }
}
