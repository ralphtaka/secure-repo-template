pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::add;

    #[test]
    fn smoke() {
        assert_eq!(add(1, 1), 2);
    }
}
