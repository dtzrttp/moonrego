///|
/// A one-based line and column paired with a zero-based source offset.
pub(all) struct SourcePos {
  offset : Int32
  line : Int32
  column : Int32
} derive(Debug, Eq)

///|
pub extend SourcePos with @debug.Debug::{to_repr}

///|
pub extend SourcePos with Eq::{equal, not_equal}

///|
/// A half-open range in one named source file.
pub(all) struct SourceSpan {
  filename : String
  start : SourcePos
  end : SourcePos
} derive(Debug, Eq)

///|
pub extend SourceSpan with @debug.Debug::{to_repr}

///|
pub extend SourceSpan with Eq::{equal, not_equal}

///|
pub fn SourceSpan::new(
  filename : String,
  start_offset~ : Int32,
  start_line~ : Int32,
  start_column~ : Int32,
  end_offset~ : Int32,
  end_line~ : Int32,
  end_column~ : Int32,
) -> SourceSpan {
  {
    filename,
    start: { offset: start_offset, line: start_line, column: start_column, },
    end: { offset: end_offset, line: end_line, column: end_column, },
  }
}

///|
pub fn SourceSpan::point(
  filename : String,
  offset : Int32,
  line : Int32,
  column : Int32,
) -> SourceSpan {
  {
    filename,
    start: { offset, line, column, },
    end: { offset, line, column, },
  }
}

///|
pub fn SourceSpan::try_join(
  self : SourceSpan,
  other : SourceSpan,
) -> SourceSpan? {
  if self.filename != other.filename {
    None
  } else {
    let start = if self.start.offset <= other.start.offset {
      self.start
    } else {
      other.start
    }
    let end = if self.end.offset >= other.end.offset {
      self.end
    } else {
      other.end
    }
    Some({ filename: self.filename, start, end, })
  }
}

///|
pub fn SourceSpan::join(self : SourceSpan, other : SourceSpan) -> SourceSpan {
  match self.try_join(other) {
    Some(span) => span
    None => abort("cannot join source spans from different files")
  }
}

///|
pub fn SourceSpan::filename(self : SourceSpan) -> String {
  self.filename
}

///|
pub fn SourceSpan::start_offset(self : SourceSpan) -> Int32 {
  self.start.offset
}

///|
pub fn SourceSpan::end_offset(self : SourceSpan) -> Int32 {
  self.end.offset
}

///|
pub fn SourceSpan::start_line(self : SourceSpan) -> Int32 {
  self.start.line
}

///|
pub fn SourceSpan::start_column(self : SourceSpan) -> Int32 {
  self.start.column
}

///|
pub fn SourceSpan::end_line(self : SourceSpan) -> Int32 {
  self.end.line
}

///|
pub fn SourceSpan::end_column(self : SourceSpan) -> Int32 {
  self.end.column
}
