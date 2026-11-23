module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    // google's 80-col / no-space-in-braces defaults fight modern TS; 100 + spaced
    // braces match every other project here.
    "max-len": ["error", { "code": 100, "ignoreUrls": true }],
    "object-curly-spacing": ["error", "always"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
  },
};
