import gleam/dict
import gleam/http
import gleam/http/request
import gleam/list
import gleeunit/should
import glimr/response/redirect
import wisp

@external(erlang, "erlang", "make_ref")
fn stub_connection() -> wisp.Connection

pub fn build_test() {
  let redir = redirect.build()

  redir.path
  |> should.equal("")

  redir.flash_data
  |> dict.to_list()
  |> should.equal([])
}

pub fn to_test() {
  redirect.build()
  |> redirect.to("/dashboard")
  |> fn(r) { r.path }
  |> should.equal("/dashboard")
}

pub fn back_test() {
  let req =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_header("referer", "https://example.com/previous-page")
    |> request.set_body(stub_connection())

  redirect.build()
  |> redirect.back(req)
  |> fn(r) { r.path }
  |> should.equal("https://example.com/previous-page")
}

pub fn flash_single_test() {
  let redir =
    redirect.build()
    |> redirect.flash([#("success", "Data saved!")])

  redir.flash_data
  |> dict.get("success")
  |> should.equal(Ok("Data saved!"))
}

pub fn flash_multiple_test() {
  let redir =
    redirect.build()
    |> redirect.flash([#("success", "Saved!"), #("info", "Check your email")])

  redir.flash_data
  |> dict.size()
  |> should.equal(2)

  redir.flash_data
  |> dict.get("success")
  |> should.equal(Ok("Saved!"))

  redir.flash_data
  |> dict.get("info")
  |> should.equal(Ok("Check your email"))
}

pub fn flash_merge_test() {
  let redir =
    redirect.build()
    |> redirect.flash([#("success", "First")])
    |> redirect.flash([#("info", "Second")])

  redir.flash_data
  |> dict.size()
  |> should.equal(2)
}

pub fn go_test() {
  let response =
    redirect.build()
    |> redirect.to("/success")
    |> redirect.go()

  response.status
  |> should.equal(303)

  // Check location header exists
  response.headers
  |> list.contains(#("location", "/success"))
  |> should.be_true()
}

pub fn go_with_normalization_test() {
  let response =
    redirect.build()
    |> redirect.to("success/")
    |> redirect.go()

  response.status
  |> should.equal(303)

  // Check location header exists and was normalized
  response.headers
  |> list.contains(#("location", "success"))
  |> should.be_true()
}

pub fn go_with_flash_test() {
  let response =
    redirect.build()
    |> redirect.to("/dashboard")
    |> redirect.flash([#("success", "Welcome!")])
    |> redirect.go()

  response.status
  |> should.equal(303)
}
