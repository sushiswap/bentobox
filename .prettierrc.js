module.exports = {
  // NOTE: This is actually the default value but it is being overwritten by
  // the solidity plugin somehow.
  bracketSpacing: true,
  trailingComma: "all",

  overrides: [
    {
      files: "*.sol",
      options: {
        bracketSpacing: false,
        printWidth: 125,
        tabWidth: 4,
        useTabs: false,
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
