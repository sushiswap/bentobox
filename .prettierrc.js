module.exports = {
  overrides: [
    {
      files: "*.sol",
      options: {
        bracketSpacing: false,
        printWidth: 125,
        tabWidth: 4,
        useTabs: true,
        singleQuote: false,
        explicitTypes: "always",
      },
    },
    {
      files: "*.js",
      options: {
        printWidth: 80,
        semi: false,
        trailingComma: "es5",
      },
    },
  ],
}
