import ACPModel

struct ACPSessionConfigurationState: Sendable {
    private(set) var modes: ACPSessionModeState?
    private(set) var configOptions: [ACPSessionConfigOption]?

    init(
        modes: ACPSessionModeState? = nil,
        configOptions: [ACPSessionConfigOption]? = nil
    ) throws {
        if let modes {
            var ids: Set<String> = []
            for mode in modes.availableModes {
                guard ids.insert(mode.id).inserted else {
                    throw ACPJSONRPCError.invalidParams
                }
            }
            guard ids.contains(modes.currentModeID) else {
                throw ACPJSONRPCError.invalidParams
            }
            self.modes = modes
        } else {
            self.modes = nil
        }
        try replaceConfigOptions(configOptions)
    }

    mutating func replaceConfigOptions(_ configOptions: [ACPSessionConfigOption]?) throws {
        guard let configOptions else {
            self.configOptions = nil
            return
        }
        var ids: Set<String> = []
        for option in configOptions {
            guard ids.insert(option.id).inserted else {
                throw ACPJSONRPCError.invalidParams
            }
            if case .select(let select) = option,
                !select.allowedValues.contains(select.currentValue)
            {
                throw ACPJSONRPCError.invalidParams
            }
        }
        self.configOptions = configOptions
    }

    func validate(modeID: String) throws {
        _ = try modes(containing: modeID)
    }

    mutating func applyCurrentMode(_ modeID: String) throws {
        let modes = try modes(containing: modeID)
        self.modes = ACPSessionModeState(
            currentModeID: modeID,
            availableModes: modes.availableModes,
            _meta: modes._meta
        )
    }

    func validate(configID: String, value: ACPSessionConfigValue) throws {
        guard let configOptions else { throw ACPJSONRPCError.methodNotFound }
        guard let option = configOptions.first(where: { $0.id == configID }) else {
            throw ACPJSONRPCError.invalidParams
        }

        switch (option, value) {
        case (.boolean, .boolean):
            return
        case (.select(let select), .valueID(let value)):
            guard select.allowedValues.contains(value) else {
                throw ACPJSONRPCError.invalidParams
            }
        default:
            throw ACPJSONRPCError.invalidParams
        }
    }

    private func modes(containing modeID: String) throws -> ACPSessionModeState {
        guard let modes else { throw ACPJSONRPCError.methodNotFound }
        guard modes.availableModes.contains(where: { $0.id == modeID }) else {
            throw ACPJSONRPCError.invalidParams
        }
        return modes
    }
}

extension ACPSessionConfigSelect {
    fileprivate var allowedValues: Set<String> {
        switch options {
        case .ungrouped(let options):
            Set(options.map(\.value))
        case .grouped(let groups):
            Set(groups.flatMap(\.options).map(\.value))
        }
    }
}
