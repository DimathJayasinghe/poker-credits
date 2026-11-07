//! One poker room: the pure reducer ([`state`] and `ops`), the public view ([`view`]) and, in
//! later modules, the actor that owns the state.

mod absence;
pub mod actor;
mod cards;
pub mod handle;
mod ops;
pub mod session;
pub mod state;
pub mod view;
