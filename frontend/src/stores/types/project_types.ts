// структуры для проектов

export type ProjectType = {
  guid: string
  name: string
  created_at: string
  updated_at: string
  created_by: number
  updated_by: number
  created_by_name: string
  updated_by_name: string
  is_deleted: boolean
  customer: string
  common_stats: number
  owner_name?: string
}

export type ExtendedProjectType = ProjectType & {
  abstract: string
  annotation_stats: number
  requirement_stats: number
  role?: string
}

export type ProjectStatsType = {
  common_stats: number
  annotation_stats: number
  abstract_paragraph_count: number
  abstract_length: number
  requirement_stats: number
  ft_count: number
  fo_count: number
}

export type RequirementType = {
  guid: string
  is_functional: boolean
  alias: string
  title: string
  priority: number
  created_at: string
  updated_at: string
  created_by: number
  updated_by: number
  created_by_name: string
  updated_by_name: string
  is_deleted: boolean
  description?: string
  project_guid?: string
}

export type ExtendedRequirementType = RequirementType

export type UserType = {
  guid: string
  name: string
  login: string
  email: string
  is_admin: boolean
  is_active: boolean
  created_at: string
  updated_at: string
}

export type MemberType = {
  id: number
  created_at: string
  created_by_name: string
  created_by_guid: string
  user_guid: string
  user_name: string
  role: string
}

export type FileInfoType = {
  guid: string
  filename: string
  file_size: number
  mime_type: string
  created_at: string
}
