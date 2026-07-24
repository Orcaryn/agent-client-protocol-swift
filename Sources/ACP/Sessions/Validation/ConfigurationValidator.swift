import ACPModel

enum ConfigurationValidator {
    static func containsBoolean(_ options: [ACPSessionConfigOption]?) -> Bool {
        options?.contains {
            if case .boolean = $0 { return true }
            return false
        } ?? false
    }

    static func containsBoolean(_ update: ACPSessionUpdate) -> Bool {
        guard case .configOptionUpdate(let configUpdate) = update else { return false }
        return containsBoolean(configUpdate.configOptions)
    }

    static func validate(
        _ options: [ACPSessionConfigOption]?,
        clientCapabilities: ACPClientCapabilities
    ) throws {
        if containsBoolean(options),
            clientCapabilities.session?.configOptions?.boolean == nil
        {
            throw ACPJSONRPCError.invalidRequest
        }
    }
}
