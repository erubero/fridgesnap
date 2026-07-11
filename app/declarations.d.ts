// Ambient module declarations for the CSS imports the Expo default template
// uses in its web components. We do not ship web, but tsc still type-checks
// those files, so declare the modules to keep the type check clean.
declare module "*.css";
declare module "*.module.css" {
  const classes: { readonly [key: string]: string };
  export default classes;
}
