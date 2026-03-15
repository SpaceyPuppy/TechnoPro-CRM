export interface PaginationOptions {
  page: number;
  pageSize: number;
}

export function parsePagination(query: { page?: number; pageSize?: number }): PaginationOptions {
  const page = Math.max(1, query.page ?? 1);
  const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 20));
  return { page, pageSize };
}

export function paginationMeta(page: number, pageSize: number, totalCount: number) {
  return {
    page,
    pageSize,
    totalCount,
    totalPages: Math.ceil(totalCount / pageSize),
  };
}
