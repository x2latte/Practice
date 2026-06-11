import { httpClient } from './base'
import { processError } from './utils'

export default {
    async uploadFile(projectGuid: string, file: File) {
        const formData = new FormData()
        formData.append('file', file)
        try {
            const response = await httpClient.post(`projects/${projectGuid}/files`, formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            })
            return response.data
        } catch (error) {
            throw processError(error)
        }
    },
    async getFiles(projectGuid: string) {
        try {
            const response = await httpClient.get(`projects/${projectGuid}/files`)
            return response.data
        } catch (error) {
            throw processError(error)
        }
    },
    async deleteFile(projectGuid: string, fileGuid: string) {
        try {
            await httpClient.delete(`projects/${projectGuid}/files/${fileGuid}`)
        } catch (error) {
            throw processError(error)
        }
    }
}
