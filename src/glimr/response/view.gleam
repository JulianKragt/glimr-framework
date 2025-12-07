//// ------------------------------------------------------------
//// View Helpers
//// ------------------------------------------------------------
////
//// Builder pattern for rendering views with layouts and 
//// template variables. Supports both static HTML files and 
//// Lustre components with automatic variable replacement.
////

import gleam/dict.{type Dict}
import gleam/string
import lustre/element.{type Element}
import simplifile
import wisp.{type Response}

// ------------------------------------------------------------- Public Types

/// ------------------------------------------------------------
/// View Type
/// ------------------------------------------------------------
///
/// View builder for constructing HTML responses with layouts.
/// Contains the content, layout template, and template 
/// variables for dynamic rendering.
///
pub type View {
  View(content: String, layout: String, data: Dict(String, String))
}

// ------------------------------------------------------------- Public Functions

/// ------------------------------------------------------------
/// Build View
/// ------------------------------------------------------------
///
/// Creates a new view with empty content, default layout, and
/// empty template data. Used internally to initialize views.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.html("contact/success.html")
/// |> view.data([#("title", "My Page")])
/// |> view.render()
/// ```
///
pub fn build() -> View {
  View(content: "", layout: get_default_layout(), data: dict.from_list([]))
}

/// ------------------------------------------------------------
/// Load HTML File
/// ------------------------------------------------------------
///
/// Creates a view from a static HTML file. The file path is
/// relative to src/resources/views/ and leading slashes are
/// automatically stripped. Panics if the file doesn't exist.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.html("contact/success.html")
/// |> view.render()
/// ```
///
pub fn html(view: View, file_path: String) -> View {
  let path = strip_leading_slashes(file_path)
  let assert Ok(content) = simplifile.read("src/resources/views/" <> path)

  View(..view, content: content)
}

/// ------------------------------------------------------------
/// Load Lustre Component
/// ------------------------------------------------------------
///
/// Creates a view from a Lustre Element by converting it to
/// an HTML string. Use for interactive components rendered
/// on the server side.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.lustre(contact_form.view(model))
/// |> view.render()
/// ```
///
pub fn lustre(view: View, content: Element(msg)) -> View {
  let content = element.to_string(content)

  View(..view, content: content)
}

/// ------------------------------------------------------------
/// Set Layout Template
/// ------------------------------------------------------------
///
/// Sets a custom layout template for the view. The layout path
/// is relative to src/resources/views/layouts/ and leading
/// slashes are stripped. Panics if layout file doesn't exist.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.html("dashboard.html")
/// |> view.layout("admin.html")
/// |> view.render()
/// ```
///
pub fn layout(view: View, layout_path: String) -> View {
  let path = strip_leading_slashes(layout_path)
  let assert Ok(layout) =
    simplifile.read("src/resources/views/layouts/" <> path)

  View(..view, layout: layout)
}

/// ------------------------------------------------------------
/// Add Template Variables
/// ------------------------------------------------------------
///
/// Adds a key-value pair to the template data. Variables are
/// replaced in the layout using {{key}} syntax. The special
/// {{_content_}} variable is reserved for the main content.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.html("page.html")
/// |> view.data([
///     #("title", "My Page"),
///     #("author", "John Doe"),
/// ])
/// |> view.render()
/// ```
///
pub fn data(view: View, data: List(#(String, String))) -> View {
  let data = dict.merge(view.data, dict.from_list(data))
  View(..view, data: data)
}

/// ------------------------------------------------------------
/// Render View
/// ------------------------------------------------------------
///
/// Converts the view builder into an HTTP response. Replaces
/// {{_content_}} with the content, substitutes all template
/// variables, and removes any unused {{variables}}.
///
/// ------------------------------------------------------------
///
/// *Example:*
/// 
/// ```gleam
/// view.build()
/// |> view.html("contact/form.html")
/// |> view.render()
/// ```
///
pub fn render(view: View) -> Response {
  let html =
    view.layout
    |> string.replace("{{_content_}}", view.content)

  let html = replace_variables(view.data, html)

  wisp.html_response(html, 200)
}

// ------------------------------------------------------------- Private Functions

/// ------------------------------------------------------------
/// Strip Leading Slashes
/// ------------------------------------------------------------
///
/// Removes the first leading slash from a string if present.
/// Used to normalize file paths for consistent reading.
///
fn strip_leading_slashes(value: String) -> String {
  case string.starts_with(value, "/") {
    True -> string.drop_start(value, 1)
    False -> value
  }
}

/// ------------------------------------------------------------
/// Replace Variables
/// ------------------------------------------------------------
///
/// Replaces all {{key}} patterns in the HTML with their values
/// from the data dictionary, then strips any unused variables
/// that weren't provided.
///
fn replace_variables(data: Dict(String, String), html: String) -> String {
  let html =
    dict.fold(data, html, fn(acc, key, value) {
      string.replace(acc, "{{" <> key <> "}}", value)
    })

  strip_unused_variables(html)
}

/// ------------------------------------------------------------
/// Strip Unused Variables
/// ------------------------------------------------------------
///
/// Recursively removes all {{variable}} patterns that weren't
/// replaced by template data. This prevents showing placeholder
/// text in the rendered output.
///
fn strip_unused_variables(html: String) -> String {
  case string.split_once(html, "{{") {
    Ok(#(before, after)) -> {
      case string.split_once(after, "}}") {
        Ok(#(_, rest)) -> before <> strip_unused_variables(rest)
        Error(_) -> html
      }
    }
    Error(_) -> html
  }
}

/// ------------------------------------------------------------
/// Get Default Layout
/// ------------------------------------------------------------
///
/// Loads default layout in src/resources/views/layouts/app.html
/// Falls back to a minimal HTML template if the file doesn't
/// exist in your codebase
///
fn get_default_layout() -> String {
  let layout_path = "src/resources/views/layouts/app.html"

  case simplifile.read(layout_path) {
    Ok(html) -> {
      html
    }
    Error(_) ->
      "<!DOCTYPE html><html><head><title>{{title}}</title></head><body>{{_content_}}</body></html>"
  }
}
