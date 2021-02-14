module.exports = {
    overrides: [
        {
            files: "*.sol",
            options: {
                bracketSpacing: false,
                printWidth: 145,
                tabWidth: 4,
                useTabs: false,
                singleQuote: false,
                explicitTypes: "always",
                endOfLine: "lf",
            },
        },
        {
            files: "*.js",
            options: {
                printWidth: 145,
                semi: false,
                trailingComma: "es5",
                tabWidth: 4,
                endOfLine: "lf",
            },
        },
        {
            files: "*.json",
            options: {
                printWidth: 145,
                semi: false,
                trailingComma: "es5",
                tabWidth: 4,
                endOfLine: "lf",
            },
        },
    ],
}
