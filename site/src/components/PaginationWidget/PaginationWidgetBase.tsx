import Button from "@mui/material/Button";
import { makeStyles, useTheme } from "@mui/styles";
import useMediaQuery from "@mui/material/useMediaQuery";
import KeyboardArrowLeft from "@mui/icons-material/KeyboardArrowLeft";
import KeyboardArrowRight from "@mui/icons-material/KeyboardArrowRight";
import { PageButton } from "./PageButton";
import { buildPagedList } from "./utils";

export type PaginationWidgetBaseProps = {
  count: number;
  page: number;
  limit: number;
  onChange: (page: number) => void;
};

export const PaginationWidgetBase = ({
  count,
  page,
  limit,
  onChange,
}: PaginationWidgetBaseProps): JSX.Element | null => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("md"));
  const styles = useStyles();
  const numPages = Math.ceil(count / limit);
  const isFirstPage = page === 0;
  const isLastPage = page === numPages - 1;

  if (numPages < 2) {
    return null;
  }

  return (
    <div className={styles.defaultContainerStyles}>
      <Button
        className={styles.prevLabelStyles}
        aria-label="Previous page"
        disabled={isFirstPage}
        onClick={() => {
          if (!isFirstPage) {
            onChange(page - 1);
          }
        }}
      >
        <KeyboardArrowLeft />
      </Button>
      {isMobile ? (
        <PageButton activePage={page} page={page} numPages={numPages} />
      ) : (
        buildPagedList(numPages, page).map((pageItem) => {
          if (pageItem === "left" || pageItem === "right") {
            return (
              <PageButton
                key={pageItem}
                activePage={page}
                placeholder="..."
                disabled
              />
            );
          }

          return (
            <PageButton
              key={pageItem}
              page={pageItem}
              activePage={page}
              numPages={numPages}
              onPageClick={() => onChange(pageItem)}
            />
          );
        })
      )}
      <Button
        aria-label="Next page"
        disabled={isLastPage}
        onClick={() => {
          if (!isLastPage) {
            onChange(page + 1);
          }
        }}
      >
        <KeyboardArrowRight />
      </Button>
    </div>
  );
};

const useStyles = makeStyles((theme) => ({
  defaultContainerStyles: {
    justifyContent: "center",
    alignItems: "center",
    display: "flex",
    flexDirection: "row",
    padding: "20px",
  },

  prevLabelStyles: {
    marginRight: theme.spacing(0.5),
  },
}));
